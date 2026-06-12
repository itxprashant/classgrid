/// CGPA / SGPA helpers (IIT 10-point grade scale + W/A/F).
const double kMinNumericGrade = 4;
const double kMaxNumericGrade = 10;

/// Numeric grades 10 down to 4, then special codes W/A/F.
const List<String> kCgpaGradeOptions = [
  '10',
  '9',
  '8',
  '7',
  '6',
  '5',
  '4',
  'W',
  'A',
  'F',
];

/// One planned course with an optional grade selection.
class CgpaCourseRow {
  const CgpaCourseRow({
    required this.code,
    this.name,
    required this.credits,
    this.gradeSelection,
  });

  final String code;
  final String? name;
  final double credits;
  /// `10`–`4`, `W`, `A`, or `F`.
  final String? gradeSelection;

  CgpaCourseRow copyWith({
    String? code,
    String? name,
    double? credits,
    String? gradeSelection,
    bool clearGrade = false,
  }) {
    return CgpaCourseRow(
      code: code ?? this.code,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      gradeSelection: clearGrade ? null : (gradeSelection ?? this.gradeSelection),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        if (name != null && name!.isNotEmpty) 'name': name,
        'credits': credits,
        if (gradeSelection != null) 'grade': gradeSelection,
      };

  factory CgpaCourseRow.fromJson(Map<String, dynamic> json) {
    final creditsRaw = json['credits'];
    final gradeRaw = json['grade'];
    String? gradeSelection;
    if (gradeRaw != null) {
      if (gradeRaw is num) {
        final n = gradeRaw.toDouble();
        if (n == n.roundToDouble() && n >= kMinNumericGrade && n <= kMaxNumericGrade) {
          gradeSelection = n.toInt().toString();
        }
      } else {
        final s = gradeRaw.toString().trim().toUpperCase();
        if (kCgpaGradeOptions.contains(s)) {
          gradeSelection = s;
        } else {
          final parsed = double.tryParse(s);
          if (parsed != null &&
              parsed == parsed.roundToDouble() &&
              parsed >= kMinNumericGrade &&
              parsed <= kMaxNumericGrade) {
            gradeSelection = parsed.toInt().toString();
          }
        }
      }
    }
    return CgpaCourseRow(
      code: (json['code'] ?? '').toString().trim(),
      name: json['name']?.toString(),
      credits: creditsRaw is num
          ? creditsRaw.toDouble()
          : double.tryParse(creditsRaw?.toString() ?? '') ?? 0,
      gradeSelection: gradeSelection,
    );
  }
}

String? normalizeGradeSelection(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase();
  if (s.isEmpty) return null;
  if (kCgpaGradeOptions.contains(s)) return s;
  final n = double.tryParse(s);
  if (n != null && n == n.roundToDouble() && n >= kMinNumericGrade && n <= kMaxNumericGrade) {
    return n.toInt().toString();
  }
  return null;
}

String gradeSelectionLabel(String? selection) {
  if (selection == null) return '—';
  switch (selection) {
    case 'W':
      return 'W';
    case 'A':
      return 'A';
    case 'F':
      return 'F';
    default:
      return selection;
  }
}

String? gradeSelectionHint(String? selection) {
  switch (selection) {
    case 'W':
      return 'Withdraw — not counted';
    case 'A':
      return 'Audit — not counted';
    case 'F':
      return 'Fail — 0 in SGPA, excluded from CGPA';
    default:
      return null;
  }
}

bool countsTowardSgpa(String? selection) {
  final g = normalizeGradeSelection(selection);
  if (g == null) return false;
  return g != 'W' && g != 'A';
}

bool countsTowardCgpa(String? selection) {
  final g = normalizeGradeSelection(selection);
  if (g == null) return false;
  return g != 'W' && g != 'A' && g != 'F';
}

double gradePointsForSgpa(String selection) {
  final g = normalizeGradeSelection(selection);
  if (g == null) return 0;
  if (g == 'F') return 0;
  return double.parse(g);
}

Iterable<CgpaCourseRow> sgpaRows(Iterable<CgpaCourseRow> rows) sync* {
  for (final row in rows) {
    if (row.credits <= 0) continue;
    if (!countsTowardSgpa(row.gradeSelection)) continue;
    yield row;
  }
}

Iterable<CgpaCourseRow> cgpaSemesterRows(Iterable<CgpaCourseRow> rows) sync* {
  for (final row in rows) {
    if (row.credits <= 0) continue;
    if (!countsTowardCgpa(row.gradeSelection)) continue;
    yield row;
  }
}

double semesterGradePointsForSgpa(Iterable<CgpaCourseRow> rows) {
  var sum = 0.0;
  for (final row in sgpaRows(rows)) {
    sum += gradePointsForSgpa(row.gradeSelection!) * row.credits;
  }
  return sum;
}

double semesterCreditsForSgpa(Iterable<CgpaCourseRow> rows) {
  var sum = 0.0;
  for (final row in sgpaRows(rows)) {
    sum += row.credits;
  }
  return sum;
}

double semesterGradePointsForCgpa(Iterable<CgpaCourseRow> rows) {
  var sum = 0.0;
  for (final row in cgpaSemesterRows(rows)) {
    sum += gradePointsForSgpa(row.gradeSelection!) * row.credits;
  }
  return sum;
}

double semesterCreditsForCgpa(Iterable<CgpaCourseRow> rows) {
  var sum = 0.0;
  for (final row in cgpaSemesterRows(rows)) {
    sum += row.credits;
  }
  return sum;
}

/// SGPA = Σ(grade × credits) / Σ(credits); W/A excluded; F counts as 0.
double? computeSgpa(Iterable<CgpaCourseRow> rows) {
  final credits = semesterCreditsForSgpa(rows);
  if (credits <= 0) return null;
  return semesterGradePointsForSgpa(rows) / credits;
}

/// CGPA projection; F/W/A semester courses excluded from the new term.
double? computeCgpa({
  required double? priorCgpa,
  required double? priorCredits,
  required Iterable<CgpaCourseRow> rows,
}) {
  if (priorCgpa == null || priorCredits == null) return null;
  if (priorCgpa.isNaN || priorCredits.isNaN || priorCredits < 0) return null;

  final semCredits = semesterCreditsForCgpa(rows);
  final semPoints = semesterGradePointsForCgpa(rows);
  final denom = priorCredits + semCredits;
  if (denom <= 0) return null;

  return (priorCgpa * priorCredits + semPoints) / denom;
}

String formatGpa(double? value, {int digits = 2}) {
  if (value == null || value.isNaN) return '—';
  return value.toStringAsFixed(digits);
}
