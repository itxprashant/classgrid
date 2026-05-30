class EnrolledStudent {
  const EnrolledStudent({required this.id, required this.name});

  final String id;
  final String name;

  factory EnrolledStudent.fromJson(Map<String, dynamic> json) {
    return EnrolledStudent(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}

class CourseRoster {
  const CourseRoster({
    required this.courseCode,
    required this.students,
  });

  final String courseCode;
  final List<EnrolledStudent> students;

  int get count => students.length;

  factory CourseRoster.fromJson(Map<String, dynamic> json) {
    final raw = json['students'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((row) => EnrolledStudent.fromJson(Map<String, dynamic>.from(row)))
            .where((s) => s.id.isNotEmpty)
            .toList()
        : <EnrolledStudent>[];
    return CourseRoster(
      courseCode: (json['courseCode'] as String? ?? '').trim(),
      students: list,
    );
  }
}
