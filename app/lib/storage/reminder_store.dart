import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/reminders_api.dart';
import '../core/planner_classes.dart';
import '../core/reminder_schedule.dart';
import '../core/semester_schedule.dart';
import '../models/calendar_event.dart';
import '../notifications/class_notification_service.dart';

/// Persisted reminder the OS should fire [minutesBefore] before [eventStart].
class ReminderEntry {
  final String key;
  final String title;
  final String body;
  final DateTime eventStart;

  const ReminderEntry({
    required this.key,
    required this.title,
    required this.body,
    required this.eventStart,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'body': body,
        'eventStart': eventStart.toIso8601String(),
      };

  Map<String, dynamic> toApiJson() => {
        'key': key,
        'title': title,
        'body': body,
        'eventStart': eventStart.toUtc().toIso8601String(),
      };

  factory ReminderEntry.fromJson(Map<String, dynamic> json) => ReminderEntry(
        key: json['key'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        eventStart: DateTime.parse(json['eventStart'] as String),
      );

  factory ReminderEntry.fromApiJson(Map<String, dynamic> json) => ReminderEntry(
        key: json['key'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        eventStart: DateTime.parse(json['eventStart'] as String).toLocal(),
      );
}

enum ReminderToggleResult {
  enabled,
  disabled,
  tooLate,
  unsupported,
  failed,
}

/// Reminder subscriptions: guests use local prefs; signed-in users sync via [RemindersApi].
class ReminderStore extends ChangeNotifier {
  ReminderStore(
    this._prefs,
    this._notifications, {
    RemindersApi? remindersApi,
  }) : _remindersApi = remindersApi;

  final SharedPreferences _prefs;
  final ClassNotificationService _notifications;
  final RemindersApi? _remindersApi;

  static const _storageKey = 'cg_reminders';
  static const _minutesKey = 'cg_reminder_minutes_before';

  final Map<String, ReminderEntry> _entries = {};
  bool _loaded = false;
  bool _syncing = false;
  bool _useApi = false;
  int _minutesBefore = kDefaultReminderMinutesBefore;

  int get minutesBefore => _minutesBefore;

  Future<void> load() async {
    _entries.clear();
    _useApi = false;
    _minutesBefore = _readMinutesBefore();
    await _loadFromPrefs();
    _loaded = true;
    await _rescheduleAll();
    notifyListeners();
  }

  int _readMinutesBefore() {
    final saved = _prefs.getInt(_minutesKey);
    if (saved != null && kReminderMinutesOptions.contains(saved)) {
      return saved;
    }
    return kDefaultReminderMinutesBefore;
  }

  /// Updates lead time and reschedules all active reminders.
  Future<void> setMinutesBefore(int minutes) async {
    if (!kReminderMinutesOptions.contains(minutes)) return;
    if (minutes == _minutesBefore) return;
    _minutesBefore = minutes;
    await _prefs.setInt(_minutesKey, minutes);
    await _rescheduleAll();
    notifyListeners();
  }

  /// Call when auth state changes (after [AuthProvider.loading] is false).
  Future<void> onAuthChanged({required bool isLoggedIn}) async {
    if (!_loaded) await load();
    if (_syncing) return;

    if (isLoggedIn && _remindersApi != null) {
      await _syncFromApi();
      return;
    }

    if (_useApi) {
      _useApi = false;
      _entries.clear();
      await _loadFromPrefs();
      await _rescheduleAll();
      notifyListeners();
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final raw = _prefs.getString(_storageKey);
      if (raw == null) return;
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      for (final item in parsed) {
        if (item is! Map) continue;
        final entry = ReminderEntry.fromJson(Map<String, dynamic>.from(item));
        _entries[entry.key] = entry;
      }
    } catch (_) {}
  }

  Future<void> _syncFromApi() async {
    final api = _remindersApi;
    if (api == null) return;

    _syncing = true;
    try {
      final localSnapshot = _entries.values.toList();
      var server = await api.fetchReminders();

      if (server.isEmpty && localSnapshot.isNotEmpty) {
        server = await api.replaceReminders(localSnapshot);
      } else if (localSnapshot.isNotEmpty) {
        final serverKeys = server.map((e) => e.key).toSet();
        final toUpload =
            localSnapshot.where((e) => !serverKeys.contains(e.key)).toList();
        for (final entry in toUpload) {
          try {
            await api.upsertReminder(entry);
          } catch (_) {}
        }
        if (toUpload.isNotEmpty) {
          server = await api.fetchReminders();
        }
      }

      _entries
        ..clear()
        ..addEntries(server.map((e) => MapEntry(e.key, e)));
      _useApi = true;
      await _persist();
      await _rescheduleAll();
      notifyListeners();
    } catch (e) {
      debugPrint('[ReminderStore] API sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  bool isEnabled(String key) => _entries.containsKey(key);

  Future<ReminderToggleResult> toggleClass(PlannerClass c, DateTime day) async {
    await _ensureLoaded();
    final key = classReminderKey(formatDateKey(day), c);
    if (_entries.containsKey(key)) {
      await _disable(key);
      return ReminderToggleResult.disabled;
    }
    return _enable(
      key: key,
      title: classReminderTitle(c),
      body: classReminderBody(c, day),
      eventStart: classEventStart(day, c),
    );
  }

  Future<ReminderToggleResult> toggleEvent(CalendarEvent e) async {
    await _ensureLoaded();
    final key = eventReminderKey(e);
    if (_entries.containsKey(key)) {
      await _disable(key);
      return ReminderToggleResult.disabled;
    }
    return _enable(
      key: key,
      title: eventReminderTitle(e),
      body: eventReminderBody(e),
      eventStart: calendarEventStart(e),
    );
  }

  Future<ReminderToggleResult> _enable({
    required String key,
    required String title,
    required String body,
    required DateTime? eventStart,
  }) async {
    if (eventStart == null) return ReminderToggleResult.unsupported;
    final notifyAt = reminderNotifyAt(eventStart, _minutesBefore);
    if (notifyAt == null || !notifyAt.isAfter(DateTime.now())) {
      return ReminderToggleResult.tooLate;
    }

    final entry = ReminderEntry(
      key: key,
      title: title,
      body: body,
      eventStart: eventStart,
    );
    final ok = await _notifications.scheduleReminder(
      key: key,
      title: title,
      body: body,
      notifyAt: notifyAt,
    );
    if (!ok) return ReminderToggleResult.failed;

    _entries[key] = entry;

    final api = _remindersApi;
    if (_useApi && api != null) {
      try {
        await api.upsertReminder(entry);
      } catch (e) {
        debugPrint('[ReminderStore] upsert failed: $e');
        await _notifications.cancelReminder(key);
        _entries.remove(key);
        return ReminderToggleResult.failed;
      }
    }

    await _persist();
    notifyListeners();
    return ReminderToggleResult.enabled;
  }

  Future<void> _disable(String key) async {
    await _notifications.cancelReminder(key);
    _entries.remove(key);

    final api = _remindersApi;
    if (_useApi && api != null) {
      try {
        await api.deleteReminder(key);
      } catch (e) {
        debugPrint('[ReminderStore] delete failed: $e');
      }
    }

    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final list = _entries.values.map((e) => e.toJson()).toList();
    await _prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  Future<void> _rescheduleAll() async {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _entries.values) {
      final notifyAt = reminderNotifyAt(entry.eventStart, _minutesBefore);
      if (notifyAt == null || !notifyAt.isAfter(now)) {
        toRemove.add(entry.key);
        await _notifications.cancelReminder(entry.key);
        continue;
      }
      await _notifications.scheduleReminder(
        key: entry.key,
        title: entry.title,
        body: entry.body,
        notifyAt: notifyAt,
      );
    }

    if (toRemove.isNotEmpty) {
      for (final k in toRemove) {
        _entries.remove(k);
      }
      await _persist();
    }
  }

}
