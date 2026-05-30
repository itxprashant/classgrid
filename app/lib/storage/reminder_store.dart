import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/planner_classes.dart';
import '../core/reminder_schedule.dart';
import '../core/semester_schedule.dart';
import '../models/calendar_event.dart';
import '../notifications/class_notification_service.dart';

/// Persisted reminder the OS should fire [kReminderMinutesBefore] before [eventStart].
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

  factory ReminderEntry.fromJson(Map<String, dynamic> json) => ReminderEntry(
        key: json['key'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        eventStart: DateTime.parse(json['eventStart'] as String),
      );
}

enum ReminderToggleResult {
  enabled,
  disabled,
  tooLate,
  unsupported,
  failed,
}

/// Enabled reminders persisted locally; schedules via [ClassNotificationService].
class ReminderStore extends ChangeNotifier {
  ReminderStore(this._prefs, this._notifications);

  final SharedPreferences _prefs;
  final ClassNotificationService _notifications;

  static const _storageKey = 'cg_reminders';

  final Map<String, ReminderEntry> _entries = {};
  bool _loaded = false;

  Future<void> load() async {
    _entries.clear();
    try {
      final raw = _prefs.getString(_storageKey);
      if (raw != null) {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is! Map) continue;
            final entry = ReminderEntry.fromJson(Map<String, dynamic>.from(item));
            _entries[entry.key] = entry;
          }
        }
      }
    } catch (_) {}
    _loaded = true;
    await _rescheduleAll();
    notifyListeners();
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
    final notifyAt = eventStart.subtract(const Duration(minutes: kReminderMinutesBefore));
    if (!notifyAt.isAfter(DateTime.now())) {
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
    await _persist();
    notifyListeners();
    return ReminderToggleResult.enabled;
  }

  Future<void> _disable(String key) async {
    await _notifications.cancelReminder(key);
    _entries.remove(key);
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
      final notifyAt =
          entry.eventStart.subtract(const Duration(minutes: kReminderMinutesBefore));
      if (!notifyAt.isAfter(now)) {
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
