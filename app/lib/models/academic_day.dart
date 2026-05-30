enum AcademicType {
  holiday,
  swapped,
  breakPeriod,
  weekend,
  beforeTerm,
  afterTerm,
  normal,
}

/// The academic meaning of a calendar date, from `getAcademicDay`.
class AcademicDay {
  final AcademicType type;
  final String weekday; // real calendar weekday, e.g. "Saturday"
  final String? effectiveDay; // weekday whose timetable runs, or null
  final int? effectiveDayCode; // 1..5 for Mon..Fri, or null
  final bool hasClasses;
  final String? name; // holiday/break label

  const AcademicDay({
    required this.type,
    required this.weekday,
    this.effectiveDay,
    this.effectiveDayCode,
    required this.hasClasses,
    this.name,
  });
}
