import 'calendar_events.dart';
import 'planner_classes.dart';
import '../models/calendar_event.dart';

const int kReminderMinutesBefore = 30;

/// Stable id for [FlutterLocalNotificationsPlugin] (positive 31-bit int).
int notificationIdForKey(String key) => key.hashCode & 0x7fffffff;

String classReminderKey(String dateKey, PlannerClass c) => 'class|$dateKey|${c.id}';

String eventReminderKey(CalendarEvent e) {
  final id = e.id?.trim();
  if (id != null && id.isNotEmpty) return 'event|$id';
  return 'event|${e.date}|${e.title}|${e.schedule}|${e.time ?? ''}|${e.start ?? ''}';
}

/// Wall-clock start of a planner class on [day].
DateTime? classEventStart(DateTime day, PlannerClass c) {
  if (c.start.length != 4) return null;
  final h = int.tryParse(c.start.substring(0, 2));
  final m = int.tryParse(c.start.substring(2, 4));
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// Wall-clock start for calendar events that have a concrete time.
DateTime? calendarEventStart(CalendarEvent e) {
  final parts = e.date.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final mo = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || mo == null || d == null) return null;

  String? hhmm;
  if (e.schedule == 'at') {
    hhmm = normalizeHHMM(e.time);
  } else if (e.schedule == 'timed') {
    hhmm = normalizeHHMM(e.start);
  } else {
    return null;
  }
  if (hhmm == null || hhmm.length != 4) return null;
  final h = int.tryParse(hhmm.substring(0, 2));
  final mi = int.tryParse(hhmm.substring(2, 4));
  if (h == null || mi == null) return null;
  return DateTime(y, mo, d, h, mi);
}

bool canRemindClass(PlannerClass c, DateTime day) {
  final start = classEventStart(day, c);
  if (start == null) return false;
  return start
      .subtract(const Duration(minutes: kReminderMinutesBefore))
      .isAfter(DateTime.now());
}

bool canRemindEvent(CalendarEvent e) {
  final start = calendarEventStart(e);
  if (start == null) return false;
  return start
      .subtract(const Duration(minutes: kReminderMinutesBefore))
      .isAfter(DateTime.now());
}

String classReminderTitle(PlannerClass c) => c.courseCode;

String classReminderBody(PlannerClass c, DateTime day) {
  final start = classEventStart(day, c);
  if (start == null) return 'Class starting soon';
  final t = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  return '${_kindLabel(c.kind)} at $t · reminder $kReminderMinutesBefore min before';
}

String eventReminderTitle(CalendarEvent e) => e.title;

String eventReminderBody(CalendarEvent e) {
  final schedule = formatEventSchedule(e);
  final when = schedule.isNotEmpty ? schedule : 'scheduled time';
  return '$when · reminder $kReminderMinutesBefore min before';
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'lecture':
      return 'Lecture';
    case 'tutorial':
      return 'Tutorial';
    case 'lab':
      return 'Lab';
    default:
      return kind;
  }
}
