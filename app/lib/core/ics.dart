import '../models/plan.dart';
import '../models/session.dart';
import 'semester_schedule.dart';
import '../models/academic_day.dart';

const Map<String, int> _dayToWeekday = {
  'Monday': 1,
  'Tuesday': 2,
  'Wednesday': 3,
  'Thursday': 4,
  'Friday': 5,
};

String _pad2(int n) => n.toString().padLeft(2, '0');

DateTime _firstDateOnOrAfter(DateTime start, int weekday) {
  // weekday: Mon=1..Fri=5 (matches JS getDay where Sun=0). Convert DateTime
  // (Mon=1..Sun=7) to JS convention for the modulo arithmetic.
  final jsDow = start.weekday % 7; // Sun=0..Sat=6
  final diff = (weekday - jsDow + 7) % 7;
  return start.add(Duration(days: diff));
}

String _formatDateYMD(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${_pad2(d.month)}${_pad2(d.day)}';

String _formatUtcStamp(DateTime date) {
  final u = date.toUtc();
  return '${u.year.toString().padLeft(4, '0')}${_pad2(u.month)}${_pad2(u.day)}'
      'T${_pad2(u.hour)}${_pad2(u.minute)}${_pad2(u.second)}Z';
}

String _escapeIcsText(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// Builds an RFC 5545 ICS string for the plan. Ported from `generateICS`
/// in the web Generator: VTIMEZONE Asia/Kolkata, weekly RRULE with UNTIL,
/// EXDATEs for holidays/breaks/swaps, and one-off VEVENTs for swap days.
String generateICS(
  List<SelectedCourse> selectedCourses,
  Map<String, CourseTimetable> timetableData,
) {
  const crlf = '\r\n';
  final lines = <String>[];
  final semesterStart = parseDateKey(Semester.classesStart);
  final semesterEnd = parseDateKey(Semester.lastTeachingDay);

  lines.add('BEGIN:VCALENDAR');
  lines.add('VERSION:2.0');
  lines.add('PRODID:-//ClassGrid//EN');
  lines.add('CALSCALE:GREGORIAN');
  lines.add('METHOD:PUBLISH');

  lines.add('BEGIN:VTIMEZONE');
  lines.add('TZID:Asia/Kolkata');
  lines.add('BEGIN:STANDARD');
  lines.add('DTSTART:19700101T000000');
  lines.add('TZOFFSETFROM:+0530');
  lines.add('TZOFFSETTO:+0530');
  lines.add('TZNAME:IST');
  lines.add('END:STANDARD');
  lines.add('END:VTIMEZONE');

  final dtstamp = _formatUtcStamp(DateTime.now());
  // UNTIL = end of the last teaching day in IST (23:59:59 IST = 18:29:59 UTC).
  final untilDate = DateTime.utc(
      semesterEnd.year, semesterEnd.month, semesterEnd.day, 18, 29, 59);
  final untilStr = _formatUtcStamp(untilDate);

  final exdatesByWeekday = <int, List<String>>{1: [], 2: [], 3: [], 4: [], 5: []};
  final swapExtrasByWeekday =
      <int, List<String>>{1: [], 2: [], 3: [], 4: [], 5: []};
  var cursor = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
  while (!cursor.isAfter(semesterEnd)) {
    final info = getAcademicDay(cursor);
    final dow = cursor.weekday % 7; // Sun=0..Sat=6
    if (info.type == AcademicType.holiday ||
        info.type == AcademicType.breakPeriod) {
      if (dow >= 1 && dow <= 5) {
        exdatesByWeekday[dow]!.add(_formatDateYMD(cursor));
      }
    } else if (info.type == AcademicType.swapped) {
      if (dow >= 1 && dow <= 5) {
        exdatesByWeekday[dow]!.add(_formatDateYMD(cursor));
      }
      if (info.effectiveDayCode != null) {
        swapExtrasByWeekday[info.effectiveDayCode]!.add(_formatDateYMD(cursor));
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  for (final course in selectedCourses) {
    final data = timetableData[course.courseCode];
    if (data == null) continue;
    final events = <MapEntry<String, Session>>[];
    for (final s in data.lecture) {
      events.add(MapEntry('Lecture', s));
    }
    for (final s in data.tutorial ?? const <Session>[]) {
      events.add(MapEntry('Tutorial', s));
    }
    for (final s in data.lab ?? const <Session>[]) {
      events.add(MapEntry('Lab', s));
    }

    for (final entry in events) {
      final type = entry.key;
      final event = entry.value;
      final weekday = _dayToWeekday[event.day];
      if (weekday == null) continue;
      final firstDate = _firstDateOnOrAfter(semesterStart, weekday);
      final datePart = _formatDateYMD(firstDate);
      final startTime = '${event.start.substring(0, 2)}${event.start.substring(2, 4)}00';
      final endTime = '${event.end.substring(0, 2)}${event.end.substring(2, 4)}00';
      final loc = (event.location?.isNotEmpty ?? false)
          ? event.location!
          : (course.lectureHall ?? '');
      final byday = event.day.substring(0, 2).toUpperCase();
      final summary =
          '${course.courseCode} $type${loc.isNotEmpty ? ' ($loc)' : ''}';
      final uid =
          '${course.courseCode}-$type-${event.day}-${event.start}@classgrid.devclub.in';

      lines.add('BEGIN:VEVENT');
      lines.add('UID:$uid');
      lines.add('DTSTAMP:$dtstamp');
      lines.add('SUMMARY:${_escapeIcsText(summary)}');
      lines.add('DTSTART;TZID=Asia/Kolkata:${datePart}T$startTime');
      lines.add('DTEND;TZID=Asia/Kolkata:${datePart}T$endTime');
      lines.add('RRULE:FREQ=WEEKLY;BYDAY=$byday;UNTIL=$untilStr');
      final exdates = exdatesByWeekday[weekday] ?? const [];
      if (exdates.isNotEmpty) {
        final exVals = exdates.map((d) => '${d}T$startTime').join(',');
        lines.add('EXDATE;TZID=Asia/Kolkata:$exVals');
      }
      if (loc.isNotEmpty) lines.add('LOCATION:${_escapeIcsText(loc)}');
      lines.add('END:VEVENT');

      final extras = swapExtrasByWeekday[weekday] ?? const [];
      for (final d in extras) {
        lines.add('BEGIN:VEVENT');
        lines.add(
            'UID:${course.courseCode}-$type-swap-$d-${event.start}@classgrid.devclub.in');
        lines.add('DTSTAMP:$dtstamp');
        lines.add('SUMMARY:${_escapeIcsText(summary)}');
        lines.add('DTSTART;TZID=Asia/Kolkata:${d}T$startTime');
        lines.add('DTEND;TZID=Asia/Kolkata:${d}T$endTime');
        if (loc.isNotEmpty) lines.add('LOCATION:${_escapeIcsText(loc)}');
        lines.add('END:VEVENT');
      }
    }
  }

  lines.add('END:VCALENDAR');
  return '${lines.join(crlf)}$crlf';
}
