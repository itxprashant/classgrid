import '../models/academic_day.dart';

/// IIT Delhi academic calendar — Semester 1, 2026-2027 (Fall 2026).
/// Ported verbatim from `src/utils/semesterSchedule.js`. Update each semester.
class Semester {
  static const String code = '2601';
  static const String label = 'Semester 1, 2026–2027';
  static const String classesStart = '2026-07-23'; // Thursday
  static const String lastTeachingDay = '2026-11-17'; // Tuesday
}

/// Days the institute runs a *different* day's timetable.
const Map<String, String> kScheduleExceptions = {
  '2026-09-03': 'Friday',
  '2026-10-10': 'Wednesday',
};

/// Institute holidays within the teaching period — no regular classes.
const Map<String, String> kHolidays = {
  '2026-08-15': 'Independence Day',
  '2026-08-26': 'Milad-un-Nabi',
  '2026-09-04': 'Janmashtami',
  '2026-10-02': "Gandhi's Birthday",
  '2026-10-20': 'Dussehra',
  '2026-11-08': 'Diwali',
  '2026-11-09': 'Govardhan Puja',
  '2026-11-24': "Guru Nanak's Birthday",
  '2026-12-25': 'Christmas',
};

class NoClassPeriod {
  final String name;
  final String start;
  final String end;
  const NoClassPeriod(this.name, this.start, this.end);
}

/// Inclusive date ranges with no regular timetabled classes.
const List<NoClassPeriod> kNoClassPeriods = [
  NoClassPeriod('Mid-semester examinations', '2026-09-12', '2026-09-18'),
  NoClassPeriod('Semester break', '2026-09-28', '2026-10-04'),
  NoClassPeriod('End-semester examinations', '2026-11-18', '2026-11-26'),
];

const List<String> _weekdays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Timetable day codes: 1=Mon … 5=Fri.
const Map<String, int> kDayNameToCode = {
  'Monday': 1,
  'Tuesday': 2,
  'Wednesday': 3,
  'Thursday': 4,
  'Friday': 5,
};

String formatDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  // DateTime months are 1-indexed (unlike JS Date), so use the part as-is.
  return DateTime(parts[0], parts[1], parts[2]);
}

int _dayValue(DateTime date) =>
    DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

NoClassPeriod? _findNoClassPeriod(DateTime date) {
  final v = _dayValue(date);
  for (final p in kNoClassPeriods) {
    if (v >= _dayValue(parseDateKey(p.start)) &&
        v <= _dayValue(parseDateKey(p.end))) {
      return p;
    }
  }
  return null;
}

/// Resolve the academic meaning of a calendar date.
/// Mirrors `getAcademicDay` in the web app.
AcademicDay getAcademicDay([DateTime? date]) {
  final d = date ?? DateTime.now();
  final key = formatDateKey(d);
  final weekday = _weekdays[d.weekday % 7]; // DateTime.weekday: Mon=1..Sun=7

  if (kHolidays.containsKey(key)) {
    return AcademicDay(
      type: AcademicType.holiday,
      weekday: weekday,
      name: kHolidays[key],
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  if (kScheduleExceptions.containsKey(key)) {
    final effectiveDay = kScheduleExceptions[key]!;
    return AcademicDay(
      type: AcademicType.swapped,
      weekday: weekday,
      effectiveDay: effectiveDay,
      effectiveDayCode: kDayNameToCode[effectiveDay],
      hasClasses: true,
    );
  }

  final v = _dayValue(d);
  if (v < _dayValue(parseDateKey(Semester.classesStart))) {
    return AcademicDay(
      type: AcademicType.beforeTerm,
      weekday: weekday,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }
  if (v > _dayValue(parseDateKey(Semester.lastTeachingDay))) {
    return AcademicDay(
      type: AcademicType.afterTerm,
      weekday: weekday,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  final period = _findNoClassPeriod(d);
  if (period != null) {
    return AcademicDay(
      type: AcademicType.breakPeriod,
      weekday: weekday,
      name: period.name,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  final dow = d.weekday % 7; // Sun=0..Sat=6
  if (dow == 0 || dow == 6) {
    return AcademicDay(
      type: AcademicType.weekend,
      weekday: weekday,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  return AcademicDay(
    type: AcademicType.normal,
    weekday: weekday,
    effectiveDay: weekday,
    effectiveDayCode: kDayNameToCode[weekday],
    hasClasses: true,
  );
}

String describeAcademicDay(AcademicDay info) {
  switch (info.type) {
    case AcademicType.holiday:
      return 'Holiday — ${info.name}. No classes scheduled.';
    case AcademicType.swapped:
      return '${info.weekday} running as per ${info.effectiveDay} timetable.';
    case AcademicType.breakPeriod:
      return '${info.name} — no regular classes.';
    case AcademicType.weekend:
      return 'Weekend — no classes scheduled.';
    case AcademicType.beforeTerm:
      return 'Term starts ${Semester.classesStart}. No classes yet.';
    case AcademicType.afterTerm:
      return 'Teaching ended ${Semester.lastTeachingDay}. No regular classes.';
    case AcademicType.normal:
      return 'Following ${info.effectiveDay} timetable.';
  }
}

bool isExamPeriod(String? name) =>
    name != null && RegExp(r'examination', caseSensitive: false).hasMatch(name);

/// Label shown in month-grid cells for institute calendar markers.
String? academicCellLabel(AcademicDay info) {
  switch (info.type) {
    case AcademicType.holiday:
      return info.name;
    case AcademicType.swapped:
      final day = info.effectiveDay ?? '';
      final short = day.length >= 3 ? day.substring(0, 3) : day;
      return '→ $short TT';
    case AcademicType.breakPeriod:
      return info.name;
    default:
      return null;
  }
}

/// Whether a day should show institute calendar info in the day dialog.
bool showAcademicInDayDialog(AcademicDay info) {
  return info.type == AcademicType.holiday ||
      info.type == AcademicType.swapped ||
      info.type == AcademicType.breakPeriod ||
      info.type == AcademicType.beforeTerm ||
      info.type == AcademicType.afterTerm;
}
