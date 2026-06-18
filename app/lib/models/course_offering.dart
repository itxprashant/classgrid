import 'instructor_ref.dart';

class CourseOffering {
  final String semesterCode;
  final String label;
  final bool isActive;
  final String courseCode;
  final String courseName;
  final String instructor;
  final String? instructorEmail;
  final List<InstructorRef> instructors;
  final String? slotName;
  final String? lectureTimingStr;
  final String? lectureTiming;
  final String? tutorialTiming;
  final String? labTiming;
  final double? credits;
  final String? creditStructure;
  final String? lectureHall;
  final String? currentStrength;

  const CourseOffering({
    required this.semesterCode,
    required this.label,
    required this.isActive,
    required this.courseCode,
    required this.courseName,
    required this.instructor,
    this.instructorEmail,
    this.instructors = const [],
    this.slotName,
    this.lectureTimingStr,
    this.lectureTiming,
    this.tutorialTiming,
    this.labTiming,
    this.credits,
    this.creditStructure,
    this.lectureHall,
    this.currentStrength,
  });

  factory CourseOffering.fromJson(Map<String, dynamic> json) {
    final instructors = instructorsFromOffering(json);
    InstructorRef? primary;
    for (final i in instructors) {
      if (i.email != null) {
        primary = i;
        break;
      }
    }
    primary ??= instructors.isNotEmpty ? instructors.first : null;
    return CourseOffering(
      semesterCode: (json['semesterCode'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      isActive: json['isActive'] == true,
      courseCode: (json['courseCode'] ?? '').toString(),
      courseName: (json['courseName'] ?? '').toString(),
      instructor: primary?.name ?? (json['instructor'] ?? '').toString(),
      instructorEmail: primary?.email ?? json['instructorEmail']?.toString(),
      instructors: instructors,
      slotName: json['slotName']?.toString(),
      lectureTimingStr: json['lectureTimingStr']?.toString(),
      lectureTiming: json['lectureTiming']?.toString(),
      tutorialTiming: json['tutorialTiming']?.toString(),
      labTiming: json['labTiming']?.toString(),
      credits: _toDouble(json['credits']),
      creditStructure: json['creditStructure']?.toString(),
      lectureHall: json['lectureHall']?.toString(),
      currentStrength: json['currentStrength']?.toString(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// Latest semester first (YYTT code); ties broken by course code.
List<CourseOffering> sortOfferingsBySemesterDesc(List<CourseOffering> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final bySemester = b.semesterCode.compareTo(a.semesterCode);
      if (bySemester != 0) return bySemester;
      return a.courseCode.compareTo(b.courseCode);
    });
  return sorted;
}
