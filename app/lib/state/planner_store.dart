import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/planner_api.dart';
import '../core/timing.dart';
import '../models/course.dart';
import '../models/plan.dart';
import '../models/session.dart';
import '../models/user.dart';
import '../storage/local_store.dart';
import 'catalog_provider.dart';

class Banner {
  final String kind; // ok | warn | err
  final String text;
  const Banner(this.kind, this.text);
}

/// Owns the planner state. Guests persist to [LocalStore]; signed-in users load
/// from `GET /api/me/plan` and debounce-save via `PUT`.
///
/// Note: the web Generator uses a "skip one save after DB load" flag because
/// React effects fire on the load-induced state update. Flutter loads do not
/// call [_persist], so that skip must not be used here — it would swallow the
/// *first user edit* and leave the server on a stale plan until a later save.
class PlannerStore extends ChangeNotifier {
  PlannerStore({
    required PlannerApi plannerApi,
    required LocalStore store,
    required CatalogProvider catalog,
  })  : _api = plannerApi,
        _store = store,
        _catalog = catalog;

  final PlannerApi _api;
  final LocalStore _store;
  final CatalogProvider _catalog;

  List<SelectedCourse> _selectedCourses = [];
  Map<String, CourseTimetable> _timetableData = {};
  bool _planReady = false;
  bool _autoFetchLoading = false;
  Banner? _banner;
  AppUser? _user;

  Timer? _saveTimer;

  List<SelectedCourse> get selectedCourses => _selectedCourses;
  Map<String, CourseTimetable> get timetableData => _timetableData;
  bool get planReady => _planReady;
  bool get autoFetchLoading => _autoFetchLoading;
  Banner? get banner => _banner;
  bool get isLoggedIn => _user != null;

  void clearBanner() {
    _banner = null;
    notifyListeners();
  }

  /// Loads the guest plan from local storage at startup.
  void initGuest() {
    final plan = _store.loadPlan();
    _selectedCourses = List.of(plan.selectedCourses);
    _timetableData = Map.of(plan.timetableData);
    _planReady = true;
    notifyListeners();
  }

  /// Called whenever auth state resolves/changes.
  Future<void> onUserChanged(AppUser? user) async {
    final wasLoggedIn = _user != null;
    _user = user;
    if (user == null) {
      // Logged out: keep whatever is local; plan is ready.
      _planReady = true;
      notifyListeners();
      return;
    }
    if (!wasLoggedIn) {
      await _loadFromDb();
    }
  }

  Future<void> _loadFromDb() async {
    _planReady = false;
    notifyListeners();
    try {
      final saved = await _api.fetchPlan();
      final hasSaved = saved.selectedCourses.isNotEmpty ||
          saved.timetableData.isNotEmpty;
      if (hasSaved) {
        _selectedCourses = List.of(saved.selectedCourses);
        _timetableData = Map.of(saved.timetableData);
        // Keep SharedPreferences aligned so a later guest path / crash mid-edit
        // does not resurrect a diverged local plan.
        await _store.savePlanLocal(currentPlan());
      } else {
        // First login with no saved plan: auto-fetch registered courses.
        await refreshUserCourses(silent: true);
      }
    } catch (e) {
      _banner = Banner('err',
          'Could not load your saved plan: ${e is ApiException ? e.message : e}');
    } finally {
      _planReady = true;
      notifyListeners();
    }
  }

  // --- Plan mutations ---

  Plan _buildPlanFromCodes(List<String> codes) {
    final newCourses = <SelectedCourse>[];
    final newTd = <String, CourseTimetable>{};
    for (final code in codes) {
      if (newCourses.any((c) => c.courseCode == code)) continue;
      final Course? course = _catalog.byCode(code);
      if (course == null) continue;
      newTd[code] = CourseTimetable(
        lecture: parseTimingStr(course.slot.lectureTiming),
        tutorial: null,
        lab: null,
      );
      newCourses.add(SelectedCourse(
        courseCode: course.courseCode,
        courseName: course.courseName,
        instructor: course.instructor,
        lecture: (course.slot.lectureTiming?.isNotEmpty ?? false),
        tutorial: course.hasTutorial,
        lab: course.hasLab,
        lectureTiming: parseTimingStr(course.slot.lectureTiming),
        tutorialTiming: parseTimingStr(course.slot.tutorialTiming),
        labTiming: parseTimingStr(course.slot.labTiming),
        creditStructure: course.creditStructure,
        totalCredits: course.totalCredits,
        lectureHall: course.lectureHall,
      ));
    }
    return Plan(selectedCourses: newCourses, timetableData: newTd);
  }

  void addCourses(List<String> codes) {
    final freshCodes = codes
        .where((c) => !_selectedCourses.any((s) => s.courseCode == c))
        .toList();
    if (freshCodes.isEmpty) return;
    final additions = _buildPlanFromCodes(freshCodes);
    _selectedCourses = [..._selectedCourses, ...additions.selectedCourses];
    _timetableData = {..._timetableData, ...additions.timetableData};
    _persist();
  }

  void removeCourse(String code) {
    _selectedCourses =
        _selectedCourses.where((c) => c.courseCode != code).toList();
    _timetableData = Map.of(_timetableData)..remove(code);
    _persist();
  }

  /// Replaces the tutorial/lab session lists for a course (lecture preserved).
  void updateCourseTimings(
    String code, {
    List<Session>? tutorial,
    List<Session>? lab,
    bool setTutorial = false,
    bool setLab = false,
  }) {
    final current = _timetableData[code];
    if (current == null) return;
    final next = current.copyWith(
      tutorial: setTutorial ? tutorial : current.tutorial,
      clearTutorial: setTutorial && (tutorial == null || tutorial.isEmpty),
      lab: setLab ? lab : current.lab,
      clearLab: setLab && (lab == null || lab.isEmpty),
    );
    _timetableData = {..._timetableData, code: next};
    _persist();
  }

  Future<void> replaceUserPlan(List<String> codes, {bool persistRemote = false}) async {
    final plan = _buildPlanFromCodes(codes);
    _selectedCourses = List.of(plan.selectedCourses);
    _timetableData = Map.of(plan.timetableData);
    await _store.savePlanLocal(currentPlan());
    notifyListeners();
    if (persistRemote && _user != null) {
      try {
        await _api.savePlan(currentPlan());
      } catch (_) {
        // SharedPreferences still holds a copy.
      }
    }
  }

  /// Auto-fetch: load registered courses and replace the plan.
  Future<void> refreshUserCourses({bool silent = false}) async {
    if (_user == null) return;
    _autoFetchLoading = true;
    if (!silent) notifyListeners();
    try {
      final codes = await _api.fetchEnrolledCourses();
      await replaceUserPlan(codes, persistRemote: true);
      if (codes.isEmpty) {
        _banner = const Banner('warn',
            'No registered courses found for your account.');
      } else {
        _banner = Banner('ok', 'Loaded ${codes.length} registered courses.');
      }
    } catch (e) {
      _banner = Banner('err',
          'Could not fetch your courses: ${e is ApiException ? e.message : e}');
    } finally {
      _autoFetchLoading = false;
      notifyListeners();
    }
  }

  Plan currentPlan() =>
      Plan(selectedCourses: _selectedCourses, timetableData: _timetableData);

  void _persist() {
    // Always cache locally (guest + signed-in).
    unawaited(_store.savePlanLocal(currentPlan()));
    notifyListeners();

    if (_user == null || !_planReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_pushRemote());
    });
  }

  Future<void> _pushRemote() async {
    if (_user == null) return;
    try {
      await _api.savePlan(currentPlan());
    } catch (_) {
      // Best-effort — local cache still holds a copy.
    }
  }

  /// Flush local + pending remote save (call on app background / dispose).
  Future<void> flushPendingSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _store.savePlanLocal(currentPlan());
    if (_user != null && _planReady) {
      await _pushRemote();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    // Best-effort sync if the store is torn down with a pending debounce.
    if (_user != null && _planReady) {
      unawaited(_pushRemote());
    }
    super.dispose();
  }
}
