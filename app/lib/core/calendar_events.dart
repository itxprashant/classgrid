import '../models/calendar_event.dart';

/// Event types and schedules ported from `src/utils/calendarEvents.js`.
const List<String> kEventTypes = [
  'quiz',
  'deadline',
  'exam',
  'extra-class',
  'presentation',
  'others',
];

const List<String> kEventSchedules = ['fullday', 'at', 'timed', 'eod'];

const Map<String, String> kScheduleLabels = {
  'fullday': 'All day',
  'at': 'At a time',
  'timed': 'Timed',
  'eod': 'EOD',
};

const Map<String, String> kEventTypeLabels = {
  'quiz': 'Quiz',
  'deadline': 'Deadline',
  'exam': 'Exam',
  'extra-class': 'Extra class',
  'presentation': 'Presentation',
  'others': 'Others',
};

String normalizeEventType(String? type) {
  if (kEventTypes.contains(type)) return type!;
  return 'others'; // 'other' and unknown -> 'others'
}

/// Returns canonical `HHMM` or null. Accepts `HH:MM` or `HHMM`.
String? normalizeHHMM(dynamic value) {
  if (value == null || value == '') return null;
  final s = value.toString().trim();
  final colon = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(s);
  if (colon != null) return '${colon.group(1)}${colon.group(2)}';
  if (RegExp(r'^\d{4}$').hasMatch(s)) return s;
  return null;
}

String hhmmToInput(String? hhmm) {
  if (hhmm == null || hhmm.length != 4) return '';
  return '${hhmm.substring(0, 2)}:${hhmm.substring(2)}';
}

String inputToHHMM(String? value) => normalizeHHMM(value) ?? '';

/// Chronological sort key for a day's events. Mirrors `eventSortKey` in MyCalendar.jsx.
String eventSortKey(CalendarEvent e) {
  if (e.schedule == 'at') return e.time ?? '0000';
  if (e.schedule == 'timed') return e.start ?? '0000';
  if (e.schedule == 'eod') return '2400';
  return '0000';
}

/// Human-readable schedule string for an event. Mirrors `formatEventSchedule`.
String formatEventSchedule(CalendarEvent e) {
  final schedule = kEventSchedules.contains(e.schedule) ? e.schedule : 'fullday';
  if (schedule == 'fullday') return '';
  if (schedule == 'eod') return 'EOD';
  String fmt(String? hhmm) {
    if (hhmm == null || hhmm.length != 4) return '';
    return '${hhmm.substring(0, 2)}:${hhmm.substring(2)}';
  }

  if (schedule == 'at') return fmt(e.time);
  if (schedule == 'timed' && e.start != null && e.end != null) {
    return '${fmt(e.start)} – ${fmt(e.end)}';
  }
  return '';
}

/// Draft of an event being edited in the form.
class EventDraft {
  String? id;
  String mode; // 'shared' | 'personal'
  String date;
  String courseCode;
  String title;
  String type;
  String schedule;
  String time;
  String start;
  String end;
  String note;

  EventDraft({
    this.id,
    required this.mode,
    required this.date,
    this.courseCode = '',
    this.title = '',
    required this.type,
    this.schedule = 'fullday',
    this.time = '',
    this.start = '',
    this.end = '',
    this.note = '',
  });

  factory EventDraft.empty(String dateKey,
      {String defaultCourseCode = '', String mode = 'shared'}) {
    return EventDraft(
      mode: mode,
      date: dateKey,
      courseCode: defaultCourseCode,
      type: mode == 'personal' ? 'others' : 'quiz',
    );
  }

  factory EventDraft.fromEvent(CalendarEvent e) {
    return EventDraft(
      id: e.id,
      mode: e.isPersonal ? 'personal' : 'shared',
      date: e.date,
      courseCode: e.courseCode ?? '',
      title: e.title,
      type: e.type,
      schedule: e.schedule,
      time: e.time ?? '',
      start: e.start ?? '',
      end: e.end ?? '',
      note: e.note ?? '',
    );
  }

  bool get isPersonal => mode == 'personal';
}

/// Validation mirroring `isDraftScheduleValid`.
bool isDraftScheduleValid(EventDraft d) {
  final schedule = kEventSchedules.contains(d.schedule) ? d.schedule : 'fullday';
  if (schedule == 'at') return normalizeHHMM(d.time) != null;
  if (schedule == 'timed') {
    final start = normalizeHHMM(d.start);
    final end = normalizeHHMM(d.end);
    return start != null && end != null && start.compareTo(end) < 0;
  }
  return true;
}

/// Whether the draft can be submitted (parity with the web submit guard).
bool isDraftSubmittable(EventDraft d) {
  if (d.title.trim().isEmpty) return false;
  if (!d.isPersonal && d.courseCode.trim().isEmpty) return false;
  return isDraftScheduleValid(d);
}

/// Builds the API/local payload from a draft.
Map<String, dynamic> draftPayload(EventDraft d) {
  final payload = <String, dynamic>{
    'date': d.date,
    'title': d.title.trim(),
    'type': d.type,
    'schedule': d.schedule,
    'time': d.time,
    'start': d.start,
    'end': d.end,
    'note': d.note,
  };
  if (!d.isPersonal) {
    payload['courseCode'] = d.courseCode;
  }
  return payload;
}
