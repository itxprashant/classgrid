import '../models/academic_day.dart';

/// Active semester schedule loaded from `GET /api/semester/schedule`.
class SemesterScheduleConfig {
  SemesterScheduleConfig({
    required this.code,
    required this.label,
    required this.classesStart,
    required this.lastTeachingDay,
    required this.holidays,
    required this.scheduleExceptions,
    required this.noClassPeriods,
  });

  final String code;
  final String label;
  final String classesStart;
  final String lastTeachingDay;
  final Map<String, String> holidays;
  final Map<String, String> scheduleExceptions;
  final List<NoClassPeriod> noClassPeriods;

  factory SemesterScheduleConfig.fromJson(Map<String, dynamic> json) {
    final semester = json['semester'];
    final semMap = semester is Map ? Map<String, dynamic>.from(semester) : <String, dynamic>{};
    final holidaysRaw = json['holidays'];
    final swapsRaw = json['scheduleExceptions'];
    final periodsRaw = json['noClassPeriods'];

    final holidays = <String, String>{};
    if (holidaysRaw is Map) {
      holidaysRaw.forEach((k, v) {
        if (k is String && v is String) holidays[k] = v;
      });
    }

    final scheduleExceptions = <String, String>{};
    if (swapsRaw is Map) {
      swapsRaw.forEach((k, v) {
        if (k is String && v is String) scheduleExceptions[k] = v;
      });
    }

    final noClassPeriods = <NoClassPeriod>[];
    if (periodsRaw is List) {
      for (final item in periodsRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final name = m['name']?.toString() ?? '';
        final start = m['start']?.toString() ?? '';
        final end = m['end']?.toString() ?? '';
        if (name.isNotEmpty && start.isNotEmpty && end.isNotEmpty) {
          noClassPeriods.add(NoClassPeriod(name, start, end));
        }
      }
    }

    return SemesterScheduleConfig(
      code: semMap['code']?.toString() ?? '',
      label: semMap['label']?.toString() ?? '',
      classesStart: semMap['classesStart']?.toString() ?? '',
      lastTeachingDay: semMap['lastTeachingDay']?.toString() ?? '',
      holidays: holidays,
      scheduleExceptions: scheduleExceptions,
      noClassPeriods: noClassPeriods,
    );
  }
}

/// Backward-compatible accessors for screens that read term bounds.
class Semester {
  static SemesterScheduleConfig get _cfg => _requireActive();
  static String get code => _cfg.code;
  static String get label => _cfg.label;
  static String get classesStart => _cfg.classesStart;
  static String get lastTeachingDay => _cfg.lastTeachingDay;
}

class NoClassPeriod {
  final String name;
  final String start;
  final String end;
  const NoClassPeriod(this.name, this.start, this.end);
}

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

SemesterScheduleConfig? _activeSchedule;

void setActiveSemesterSchedule(SemesterScheduleConfig? config) {
  _activeSchedule = config;
}

SemesterScheduleConfig? get activeSemesterSchedule => _activeSchedule;

SemesterScheduleConfig _requireActive() {
  final cfg = _activeSchedule;
  if (cfg == null) {
    throw StateError('Semester schedule not loaded');
  }
  return cfg;
}

String formatDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

int _dayValue(DateTime date) =>
    DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

NoClassPeriod? _findNoClassPeriod(SemesterScheduleConfig cfg, DateTime date) {
  final v = _dayValue(date);
  for (final p in cfg.noClassPeriods) {
    if (v >= _dayValue(parseDateKey(p.start)) &&
        v <= _dayValue(parseDateKey(p.end))) {
      return p;
    }
  }
  return null;
}

AcademicDay getAcademicDayForConfig(SemesterScheduleConfig cfg, [DateTime? date]) {
  final d = date ?? DateTime.now();
  final key = formatDateKey(d);
  final weekday = _weekdays[d.weekday % 7];

  if (cfg.holidays.containsKey(key)) {
    return AcademicDay(
      type: AcademicType.holiday,
      weekday: weekday,
      name: cfg.holidays[key],
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  if (cfg.scheduleExceptions.containsKey(key)) {
    final effectiveDay = cfg.scheduleExceptions[key]!;
    return AcademicDay(
      type: AcademicType.swapped,
      weekday: weekday,
      effectiveDay: effectiveDay,
      effectiveDayCode: kDayNameToCode[effectiveDay],
      hasClasses: true,
    );
  }

  final v = _dayValue(d);
  if (cfg.classesStart.isNotEmpty &&
      v < _dayValue(parseDateKey(cfg.classesStart))) {
    return AcademicDay(
      type: AcademicType.beforeTerm,
      weekday: weekday,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }
  if (cfg.lastTeachingDay.isNotEmpty &&
      v > _dayValue(parseDateKey(cfg.lastTeachingDay))) {
    return AcademicDay(
      type: AcademicType.afterTerm,
      weekday: weekday,
      effectiveDay: null,
      effectiveDayCode: null,
      hasClasses: false,
    );
  }

  final period = _findNoClassPeriod(cfg, d);
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

  final dow = d.weekday % 7;
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

AcademicDay getAcademicDay([DateTime? date]) =>
    getAcademicDayForConfig(_requireActive(), date);

String describeAcademicDay(AcademicDay info) {
  final cfg = _requireActive();
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
      return 'Term starts ${cfg.classesStart}. No classes yet.';
    case AcademicType.afterTerm:
      return 'Teaching ended ${cfg.lastTeachingDay}. No regular classes.';
    case AcademicType.normal:
      return 'Following ${info.effectiveDay} timetable.';
  }
}

bool isExamPeriod(String? name) =>
    name != null && RegExp(r'examination', caseSensitive: false).hasMatch(name);

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

String? academicWeekHeadLabel(AcademicDay info) {
  switch (info.type) {
    case AcademicType.holiday:
      return info.name;
    case AcademicType.swapped:
      final day = info.effectiveDay;
      return day != null ? '→ $day TT' : null;
    case AcademicType.breakPeriod:
      return info.name;
    case AcademicType.weekend:
      return 'Weekend';
    case AcademicType.beforeTerm:
      return 'Before term';
    case AcademicType.afterTerm:
      return 'After term';
    default:
      return null;
  }
}

bool showAcademicInDayDialog(AcademicDay info) {
  return info.type == AcademicType.holiday ||
      info.type == AcademicType.swapped ||
      info.type == AcademicType.breakPeriod ||
      info.type == AcademicType.beforeTerm ||
      info.type == AcademicType.afterTerm;
}

/// Default config for unit tests (matches data/academic_calendar.json).
SemesterScheduleConfig testSemesterScheduleConfig() => SemesterScheduleConfig.fromJson({
      'semester': {
        'code': '2601',
        'label': 'Semester 1, 2026–2027',
        'classesStart': '2026-07-23',
        'lastTeachingDay': '2026-11-17',
      },
      'holidays': {
        '2026-08-15': 'Independence Day',
        '2026-08-26': 'Milad-un-Nabi',
        '2026-09-04': 'Janmashtami',
        '2026-10-02': "Gandhi's Birthday",
        '2026-10-20': 'Dussehra',
        '2026-11-08': 'Diwali',
        '2026-11-09': 'Govardhan Puja',
        '2026-11-24': "Guru Nanak's Birthday",
        '2026-12-25': 'Christmas',
      },
      'scheduleExceptions': {
        '2026-09-03': 'Friday',
        '2026-10-10': 'Wednesday',
      },
      'noClassPeriods': [
        {'name': 'Mid-semester examinations', 'start': '2026-09-12', 'end': '2026-09-18'},
        {'name': 'Semester break', 'start': '2026-09-28', 'end': '2026-10-04'},
        {'name': 'End-semester examinations', 'start': '2026-11-18', 'end': '2026-11-26'},
      ],
    });

/// Legacy aliases used by a few widgets.
Map<String, String> get kHolidays => _requireActive().holidays;
Map<String, String> get kScheduleExceptions => _requireActive().scheduleExceptions;
List<NoClassPeriod> get kNoClassPeriods => _requireActive().noClassPeriods;
