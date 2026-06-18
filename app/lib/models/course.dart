import 'course_offering.dart';

/// A course-catalog slot. Timing strings are the raw `DHHMMHHMM` format.
class Slot {
  final String? name;
  final String? lectureTiming;
  final String? lectureTimingStr;
  final String? tutorialTiming;
  final String? labTiming;

  const Slot({
    this.name,
    this.lectureTiming,
    this.lectureTimingStr,
    this.tutorialTiming,
    this.labTiming,
  });

  factory Slot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Slot();
    return Slot(
      name: json['name']?.toString(),
      lectureTiming: json['lectureTiming']?.toString(),
      lectureTimingStr: json['lectureTimingStr']?.toString(),
      tutorialTiming: json['tutorialTiming']?.toString(),
      labTiming: json['labTiming']?.toString(),
    );
  }
}

/// A full catalog entry from `courses.json` / `GET /api/catalog`.
class Course {
  final String courseCode;
  final String courseName;
  final String? semesterCode;
  final double totalCredits;
  final String creditStructure; // "L-T-Lab", e.g. "3.0-1.0-0.0"
  final String? instructor;
  final String? instructorEmail;
  final String? currentStrength;
  final Slot slot;
  final String? lectureHall;
  final bool offeredThisSemester;

  const Course({
    required this.courseCode,
    required this.courseName,
    this.semesterCode,
    required this.totalCredits,
    required this.creditStructure,
    this.instructor,
    this.instructorEmail,
    this.currentStrength,
    required this.slot,
    this.lectureHall,
    this.offeredThisSemester = true,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseCode: (json['courseCode'] ?? '').toString(),
      courseName: (json['courseName'] ?? '').toString(),
      semesterCode: json['semesterCode']?.toString(),
      totalCredits: _toDouble(json['totalCredits']),
      creditStructure: (json['creditStructure'] ?? '0.0-0.0-0.0').toString(),
      instructor: json['instructor']?.toString(),
      instructorEmail: json['instructorEmail']?.toString(),
      currentStrength: json['currentStrength']?.toString(),
      slot: Slot.fromJson(json['slot'] as Map<String, dynamic>?),
      lectureHall: json['lectureHall']?.toString(),
      offeredThisSemester: json['offeredThisSemester'] != false,
    );
  }

  /// Build a catalog-shaped course from a historical offering row.
  factory Course.fromOffering(CourseOffering offering, {required bool offeredThisSemester}) {
    return Course(
      courseCode: offering.courseCode,
      courseName: offering.courseName,
      semesterCode: offering.semesterCode,
      totalCredits: offering.credits ?? 0,
      creditStructure: offering.creditStructure ?? '0.0-0.0-0.0',
      instructor: offering.instructor.isNotEmpty ? offering.instructor : null,
      instructorEmail: offering.instructorEmail,
      currentStrength: offering.currentStrength,
      slot: Slot(
        name: offering.slotName,
        lectureTiming: offering.lectureTiming,
        lectureTimingStr: offering.lectureTimingStr,
        tutorialTiming: offering.tutorialTiming,
        labTiming: offering.labTiming,
      ),
      lectureHall: offering.lectureHall,
      offeredThisSemester: offeredThisSemester,
    );
  }

  /// Department prefix: first two letters of the course code (e.g. COL106 -> CO).
  String get department =>
      courseCode.length >= 2 ? courseCode.substring(0, 2).toUpperCase() : courseCode;

  bool get hasTutorial {
    final parts = creditStructure.split('-');
    return parts.length > 1 && parts[1] != '0.0';
  }

  bool get hasLab {
    final parts = creditStructure.split('-');
    return parts.length > 2 && parts[2] != '0.0';
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}
