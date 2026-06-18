import 'course_offering.dart';

class InstructorSummary {
  final String name;
  final String email;
  final int offeringCount;

  const InstructorSummary({
    required this.name,
    required this.email,
    required this.offeringCount,
  });

  factory InstructorSummary.fromJson(Map<String, dynamic> json) {
    return InstructorSummary(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      offeringCount: json['offeringCount'] is int
          ? json['offeringCount'] as int
          : int.tryParse(json['offeringCount']?.toString() ?? '') ?? 0,
    );
  }
}

class InstructorOfferings {
  final InstructorSummary instructor;
  final List<CourseOffering> offerings;

  const InstructorOfferings({
    required this.instructor,
    required this.offerings,
  });

  factory InstructorOfferings.fromJson(Map<String, dynamic> json) {
    final inst = json['instructor'] as Map<String, dynamic>? ?? {};
    final list = json['offerings'] as List<dynamic>? ?? [];
    return InstructorOfferings(
      instructor: InstructorSummary(
        name: (inst['name'] ?? '').toString(),
        email: (inst['email'] ?? '').toString(),
        offeringCount: list.length,
      ),
      offerings: list
          .whereType<Map<String, dynamic>>()
          .map(CourseOffering.fromJson)
          .toList(),
    );
  }
}
