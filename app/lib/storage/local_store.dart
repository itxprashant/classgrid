import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../models/plan.dart';

/// Persists guest state in SharedPreferences using the same key names and JSON
/// shapes as the web app's `localStorage`, so behaviour matches across guests.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  SharedPreferences get sharedPreferences => _prefs;

  static const _kSelectedCourses = 'selectedCourses';
  static const _kTimetableData = 'timetableData';
  static const _kCalendarEvents = 'cg_calendar_events';
  static const _kCatalog = 'cg_catalog_cache';
  static const _kCatalogEtag = 'cg_catalog_etag';

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  // --- Planner ---

  Plan loadPlan() {
    try {
      final scRaw = _prefs.getString(_kSelectedCourses);
      final tdRaw = _prefs.getString(_kTimetableData);
      final sc = scRaw != null ? jsonDecode(scRaw) : [];
      final td = tdRaw != null ? jsonDecode(tdRaw) : {};
      return Plan.fromJson({'selectedCourses': sc, 'timetableData': td});
    } catch (_) {
      return const Plan();
    }
  }

  Future<void> savePlanLocal(Plan plan) async {
    await _prefs.setString(
        _kSelectedCourses, jsonEncode(plan.selectedCourses.map((e) => e.toJson()).toList()));
    await _prefs.setString(_kTimetableData,
        jsonEncode(plan.timetableData.map((k, v) => MapEntry(k, v.toJson()))));
  }

  // --- Guest personal calendar events ---

  List<CalendarEvent> loadLocalPersonalEvents({String? from, String? to}) {
    try {
      final raw = _prefs.getString(_kCalendarEvents);
      if (raw == null) return [];
      final parsed = jsonDecode(raw);
      if (parsed is! List) return [];
      var events = parsed
          .whereType<Map>()
          .map((e) => CalendarEvent.fromJson(
              {...Map<String, dynamic>.from(e), 'isPersonal': true}))
          .where((e) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e.date))
          .toList();
      if (from != null && to != null) {
        events = events
            .where((e) => e.date.compareTo(from) >= 0 && e.date.compareTo(to) <= 0)
            .toList();
      }
      return events;
    } catch (_) {
      return [];
    }
  }

  List<CalendarEvent> _allLocalEvents() {
    try {
      final raw = _prefs.getString(_kCalendarEvents);
      if (raw == null) return [];
      final parsed = jsonDecode(raw);
      if (parsed is! List) return [];
      return parsed
          .whereType<Map>()
          .map((e) => CalendarEvent.fromJson(
              {...Map<String, dynamic>.from(e), 'isPersonal': true}))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalEvents(List<CalendarEvent> events) async {
    await _prefs.setString(_kCalendarEvents,
        jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<CalendarEvent> addLocalPersonalEvent(CalendarEvent event) async {
    final all = _allLocalEvents();
    final withId = event.id == null
        ? CalendarEvent.fromJson({
            ...event.toJson(),
            'id': 'evt_${DateTime.now().microsecondsSinceEpoch}',
            'isPersonal': true,
          })
        : event;
    all.add(withId);
    await _saveLocalEvents(all);
    return withId;
  }

  Future<CalendarEvent> updateLocalPersonalEvent(
      String id, CalendarEvent updated) async {
    final all = _allLocalEvents();
    final idx = all.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      all[idx] = CalendarEvent.fromJson({...updated.toJson(), 'id': id, 'isPersonal': true});
      await _saveLocalEvents(all);
      return all[idx];
    }
    return updated;
  }

  Future<void> deleteLocalPersonalEvent(String id) async {
    final all = _allLocalEvents()..removeWhere((e) => e.id == id);
    await _saveLocalEvents(all);
  }

  Future<List<CalendarEvent>> drainLocalPersonalEvents() async {
    final all = _allLocalEvents();
    await _prefs.remove(_kCalendarEvents);
    return all;
  }

  // --- Catalog cache ---

  List<dynamic>? loadCatalogCache() {
    try {
      final raw = _prefs.getString(_kCatalog);
      if (raw == null) return null;
      final parsed = jsonDecode(raw);
      return parsed is List ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCatalogCache(List<dynamic> coursesJson, String? etag) async {
    await _prefs.setString(_kCatalog, jsonEncode(coursesJson));
    if (etag != null) await _prefs.setString(_kCatalogEtag, etag);
  }
}
