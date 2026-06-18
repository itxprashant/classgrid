import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/attendance_api.dart';
import '../core/attendance.dart';
import '../core/planner_classes.dart';
import '../core/semester_schedule.dart';
import '../models/plan.dart';
import '../notifications/class_notification_service.dart';

/// Pending navigation from an attendance notification tap.
class AttendanceNavTarget {
  final String courseCode;
  final String sessionKind;
  final String date;

  const AttendanceNavTarget({
    required this.courseCode,
    required this.sessionKind,
    required this.date,
  });
}

/// Attendance buckets: guests use local prefs; signed-in users sync via [AttendanceApi].
class AttendanceStore extends ChangeNotifier {
  AttendanceStore(
    this._prefs,
    this._notifications, {
    AttendanceApi? attendanceApi,
  }) : _attendanceApi = attendanceApi;

  final SharedPreferences _prefs;
  final ClassNotificationService _notifications;
  final AttendanceApi? _attendanceApi;

  static const _bucketsKey = 'cg_attendance_buckets';
  static const _thresholdsKey = 'cg_attendance_thresholds';
  static const _markNotifyKey = 'cg_attendance_mark_notify';

  final Map<String, AttendanceBucket> _buckets = {};
  final Map<String, int> _courseThresholds = {};
  bool _loaded = false;
  bool _syncing = false;
  bool _useApi = false;
  bool _markNotifyEnabled = false;
  AttendanceNavTarget? _pendingNav;
  String? _syncError;

  Timer? _patchTimer;
  String? _patchCourse;
  String? _patchKind;
  String? _patchDate;
  String? _patchStatus;

  Map<String, AttendanceBucket> get buckets => Map.unmodifiable(_buckets);
  bool get markNotifyEnabled => _markNotifyEnabled;
  String? get syncError => _syncError;

  void clearSyncError() {
    if (_syncError == null) return;
    _syncError = null;
    notifyListeners();
  }

  int thresholdFor(String courseCode) =>
      _courseThresholds[courseCode] ?? kDefaultAttendanceThreshold;
  AttendanceNavTarget? consumePendingNav() {
    final v = _pendingNav;
    _pendingNav = null;
    return v;
  }

  Future<void> load() async {
    _buckets.clear();
    _useApi = false;
    _markNotifyEnabled = _prefs.getBool(_markNotifyKey) ?? false;
    await _loadThresholds();
    await _loadFromPrefs();
    _loaded = true;
    notifyListeners();
  }

  Future<void> onAuthChanged({required bool isLoggedIn}) async {
    if (!_loaded) await load();
    if (_syncing) return;

    if (isLoggedIn && _attendanceApi != null) {
      await _syncFromApi();
      return;
    }

    if (_useApi) {
      _useApi = false;
      _buckets.clear();
      await _loadFromPrefs();
      notifyListeners();
    }
  }

  Future<void> _loadThresholds() async {
    _courseThresholds.clear();
    try {
      final raw = _prefs.getString(_thresholdsKey);
      if (raw != null) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          for (final e in parsed.entries) {
            final code = e.key.toString().trim();
            final v = e.value;
            if (code.isEmpty || v is! num) continue;
            _courseThresholds[code] = v.toInt().clamp(50, 100);
          }
        }
      }
      // Legacy global threshold → default only (not copied to every course).
      final legacy = _prefs.getInt('cg_attendance_threshold');
      if (legacy != null && _courseThresholds.isEmpty) {
        // No per-course overrides stored yet; keep using default per course.
      }
    } catch (_) {}
  }

  Future<void> _persistThresholds() async {
    await _prefs.setString(_thresholdsKey, jsonEncode(_courseThresholds));
  }

  Future<void> _loadFromPrefs() async {
    try {
      final raw = _prefs.getString(_bucketsKey);
      if (raw == null) return;
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      for (final item in parsed) {
        if (item is! Map) continue;
        final bucket = AttendanceBucket.fromJson(Map<String, dynamic>.from(item));
        _buckets[bucket.bucketKey()] = bucket;
      }
    } catch (_) {}
  }

  Future<void> _syncFromApi() async {
    final api = _attendanceApi;
    if (api == null) return;

    _syncing = true;
    try {
      final localSnapshot = _buckets.values.toList();
      var server = await api.fetchBuckets();

      if (server.isEmpty && localSnapshot.isNotEmpty) {
        server = await api.replaceBuckets(localSnapshot);
      }

      _buckets
        ..clear()
        ..addEntries(server.map((b) => MapEntry(b.bucketKey(), b)));
      _useApi = true;
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('[AttendanceStore] API sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> setCourseThreshold(String courseCode, int value) async {
    final code = courseCode.trim();
    if (code.isEmpty) return;
    final clamped = value.clamp(50, 100);
    if (thresholdFor(code) == clamped && _courseThresholds.containsKey(code)) {
      return;
    }
    if (clamped == kDefaultAttendanceThreshold) {
      _courseThresholds.remove(code);
    } else {
      _courseThresholds[code] = clamped;
    }
    await _persistThresholds();
    notifyListeners();
  }

  Future<void> setMarkNotifyEnabled(bool enabled) async {
    if (_markNotifyEnabled == enabled) return;
    _markNotifyEnabled = enabled;
    await _prefs.setBool(_markNotifyKey, enabled);
    notifyListeners();
  }

  AttendanceBucket? bucketFor(String courseCode, String sessionKind) =>
      _buckets['$courseCode|$sessionKind'];

  String? statusFor(String courseCode, String sessionKind, String dateKey) =>
      bucketFor(courseCode, sessionKind)?.byDate[dateKey];

  Future<void> markSession({
    required String courseCode,
    required String sessionKind,
    required String dateKey,
    String? status,
    PlannerClass? plannerClass,
    List<SelectedCourse> courses = const [],
    Map<String, CourseTimetable> timetableData = const {},
  }) async {
    await _ensureLoaded();

    var bucket = getOrCreateBucket(_buckets, courseCode, sessionKind);
    bucket = applyMark(bucket, dateKey, newStatus: status);
    _buckets[bucket.bucketKey()] = bucket;
    notifyListeners();

    _patchCourse = courseCode;
    _patchKind = sessionKind;
    _patchDate = dateKey;
    _patchStatus = status;
    _patchTimer?.cancel();
    _patchTimer = Timer(const Duration(milliseconds: 400), _flushPatch);

    await _persistLocal();

    if (plannerClass != null) {
      await _notifications.cancelReminder(attendPromptKey(dateKey, plannerClass));
    }
    if (courses.isNotEmpty) {
      await rescheduleMarkPrompts(courses: courses, timetableData: timetableData);
    }
  }

  Future<void> _flushPatch() async {
    final course = _patchCourse;
    final kind = _patchKind;
    final date = _patchDate;
    if (course == null || kind == null || date == null) return;

    final status = _patchStatus;
    _patchCourse = null;
    _patchKind = null;
    _patchDate = null;
    _patchStatus = null;

    if (_useApi && _attendanceApi != null) {
      try {
        final updated = await _attendanceApi.patchMark(
          courseCode: course,
          sessionKind: kind,
          date: date,
          status: status,
        );
        _buckets[updated.bucketKey()] = updated;
        _syncError = null;
        await _persistLocal();
        notifyListeners();
      } catch (e) {
        debugPrint('[AttendanceStore] patch failed: $e');
        _syncError = 'Could not sync attendance mark. Saved on this device.';
        notifyListeners();
      }
    }
  }

  Future<void> _persistLocal() async {
    final list = _buckets.values.map((b) => b.toJson()).toList();
    await _prefs.setString(_bucketsKey, jsonEncode(list));
  }

  Future<void> _persist() async {
    await _persistLocal();
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  /// Reschedule post-class mark prompts for the next [kAttendancePromptDaysAhead] days.
  Future<void> rescheduleMarkPrompts({
    required List<SelectedCourse> courses,
    required Map<String, CourseTimetable> timetableData,
  }) async {
    if (!_loaded) await load();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: kAttendancePromptDaysAhead));

    if (!_markNotifyEnabled) {
      await _cancelAllAttendPrompts();
      return;
    }

    final desiredKeys = <String>{};
    var cursor = today;
    while (!cursor.isAfter(end)) {
      final classes = getClassesForDate(cursor, courses, timetableData);
      for (final c in classes) {
        final dateKey = formatDateKey(cursor);
        if (statusFor(c.courseCode, c.kind, dateKey) != null) continue;
        final endAt = classEventEnd(cursor, c);
        if (endAt == null || !endAt.isAfter(now)) continue;

        final key = attendPromptKey(dateKey, c);
        desiredKeys.add(key);
        final payload = jsonEncode({
          'type': 'attendance_mark',
          'courseCode': c.courseCode,
          'sessionKind': c.kind,
          'date': dateKey,
        });
        await _notifications.scheduleAttendancePrompt(
          key: key,
          title: attendanceMarkPromptTitle(c),
          body: attendanceMarkPromptBody(c),
          notifyAt: endAt,
          payload: payload,
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    await _notifications.cancelAttendPromptsExcept(desiredKeys);
  }

  Future<void> _cancelAllAttendPrompts() async {
    await _notifications.cancelAttendPromptsExcept({});
  }

  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final parsed = jsonDecode(payload);
      if (parsed is! Map) return;
      if (parsed['type'] != 'attendance_mark') return;
      final course = parsed['courseCode']?.toString();
      final kind = parsed['sessionKind']?.toString();
      final date = parsed['date']?.toString();
      if (course == null || kind == null || date == null) return;
      _pendingNav = AttendanceNavTarget(
        courseCode: course,
        sessionKind: kind,
        date: date,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> onPlannerChanged({
    required List<SelectedCourse> courses,
    required Map<String, CourseTimetable> timetableData,
  }) async {
    await rescheduleMarkPrompts(courses: courses, timetableData: timetableData);
  }

}
