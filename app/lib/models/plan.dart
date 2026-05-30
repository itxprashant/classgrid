import 'session.dart';

List<Session> _sessions(dynamic v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => Session.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _sessionsJson(List<Session> s) =>
    s.map((e) => e.toJson()).toList();

/// A course summary on the plan. JSON shape matches the web's `selectedCourses`
/// entries so plans round-trip through `localStorage` and `PUT /api/me/plan`.
class SelectedCourse {
  final String courseCode;
  final String courseName;
  final String? instructor;
  final bool lecture;
  final bool tutorial;
  final bool lab;
  final List<Session> lectureTiming;
  final List<Session> tutorialTiming;
  final List<Session> labTiming;
  final String creditStructure;
  final double totalCredits;
  final String? lectureHall;

  const SelectedCourse({
    required this.courseCode,
    required this.courseName,
    this.instructor,
    required this.lecture,
    required this.tutorial,
    required this.lab,
    required this.lectureTiming,
    required this.tutorialTiming,
    required this.labTiming,
    required this.creditStructure,
    required this.totalCredits,
    this.lectureHall,
  });

  factory SelectedCourse.fromJson(Map<String, dynamic> json) => SelectedCourse(
        courseCode: (json['courseCode'] ?? '').toString(),
        courseName: (json['courseName'] ?? '').toString(),
        instructor: json['instructor']?.toString(),
        lecture: json['lecture'] == true,
        tutorial: json['tutorial'] == true,
        lab: json['lab'] == true,
        lectureTiming: _sessions(json['lectureTiming']),
        tutorialTiming: _sessions(json['tutorialTiming']),
        labTiming: _sessions(json['labTiming']),
        creditStructure: (json['creditStructure'] ?? '0.0-0.0-0.0').toString(),
        totalCredits: json['totalCredits'] is num
            ? (json['totalCredits'] as num).toDouble()
            : double.tryParse(json['totalCredits']?.toString() ?? '') ?? 0.0,
        lectureHall: json['lectureHall']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'courseCode': courseCode,
        'courseName': courseName,
        'instructor': instructor,
        'lecture': lecture,
        'tutorial': tutorial,
        'lab': lab,
        'lectureTiming': _sessionsJson(lectureTiming),
        'tutorialTiming': _sessionsJson(tutorialTiming),
        'labTiming': _sessionsJson(labTiming),
        'creditStructure': creditStructure,
        'totalCredits': totalCredits,
        'lectureHall': lectureHall,
      };
}

/// Per-course timetable entry: `{ lecture, tutorial?, lab? }`.
/// `tutorial`/`lab` are null when the user has not configured any sessions.
class CourseTimetable {
  final List<Session> lecture;
  final List<Session>? tutorial;
  final List<Session>? lab;

  const CourseTimetable({
    required this.lecture,
    this.tutorial,
    this.lab,
  });

  factory CourseTimetable.fromJson(Map<String, dynamic> json) => CourseTimetable(
        lecture: _sessions(json['lecture']),
        tutorial: json['tutorial'] == null ? null : _sessions(json['tutorial']),
        lab: json['lab'] == null ? null : _sessions(json['lab']),
      );

  Map<String, dynamic> toJson() => {
        'lecture': _sessionsJson(lecture),
        'tutorial': tutorial == null ? null : _sessionsJson(tutorial!),
        'lab': lab == null ? null : _sessionsJson(lab!),
      };

  CourseTimetable copyWith({
    List<Session>? lecture,
    List<Session>? tutorial,
    List<Session>? lab,
    bool clearTutorial = false,
    bool clearLab = false,
  }) =>
      CourseTimetable(
        lecture: lecture ?? this.lecture,
        tutorial: clearTutorial ? null : (tutorial ?? this.tutorial),
        lab: clearLab ? null : (lab ?? this.lab),
      );
}

/// A full plan: the selected-course list plus the timetable map keyed by code.
class Plan {
  final List<SelectedCourse> selectedCourses;
  final Map<String, CourseTimetable> timetableData;
  final String? updatedAt;

  const Plan({
    this.selectedCourses = const [],
    this.timetableData = const {},
    this.updatedAt,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final scRaw = json['selectedCourses'];
    final tdRaw = json['timetableData'];
    return Plan(
      selectedCourses: scRaw is List
          ? scRaw
              .whereType<Map>()
              .map((e) => SelectedCourse.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      timetableData: tdRaw is Map
          ? tdRaw.map((k, v) => MapEntry(
                k.toString(),
                CourseTimetable.fromJson(Map<String, dynamic>.from(v as Map)),
              ))
          : const {},
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedCourses': selectedCourses.map((e) => e.toJson()).toList(),
        'timetableData': timetableData.map((k, v) => MapEntry(k, v.toJson())),
      };
}
