import 'course_offering.dart';

class StudentSummary {
  final String kerberos;
  final String name;
  final int enrollmentCount;
  final String? branch;
  final String? entryYear;
  final String? hostel;

  const StudentSummary({
    required this.kerberos,
    required this.name,
    required this.enrollmentCount,
    this.branch,
    this.entryYear,
    this.hostel,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      kerberos: (json['kerberos'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      enrollmentCount: json['enrollmentCount'] is int
          ? json['enrollmentCount'] as int
          : int.tryParse(json['enrollmentCount']?.toString() ?? '') ?? 0,
      branch: json['branch']?.toString(),
      entryYear: json['entryYear']?.toString(),
      hostel: json['hostel']?.toString(),
    );
  }
}

class StudentOfferings {
  final StudentSummary student;
  final List<CourseOffering> offerings;

  const StudentOfferings({
    required this.student,
    required this.offerings,
  });

  factory StudentOfferings.fromJson(Map<String, dynamic> json) {
    final studentJson = json['student'] as Map<String, dynamic>? ?? {};
    final list = json['offerings'] as List<dynamic>? ?? [];
    return StudentOfferings(
      student: StudentSummary.fromJson(studentJson),
      offerings: list
          .whereType<Map<String, dynamic>>()
          .map(CourseOffering.fromJson)
          .toList(),
    );
  }
}
