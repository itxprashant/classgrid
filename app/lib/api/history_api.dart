import '../api/api_client.dart';
import '../models/course_offering.dart';
import '../models/instructor_summary.dart';
import '../models/student_summary.dart';

class HistoryApi {
  HistoryApi(this._client);

  final ApiClient _client;

  Future<List<CourseOffering>> fetchCourseOfferings(String courseCode) async {
    final code = courseCode.trim().toUpperCase();
    final data = await _client.requestJson('/api/courses/$code/offerings');
    final list = data['offerings'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().map(CourseOffering.fromJson).toList();
  }

  Future<List<InstructorSummary>> searchInstructors(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final data = await _client.requestJson(
      '/api/instructors/search',
      query: {'q': q},
    );
    final list = data['results'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().map(InstructorSummary.fromJson).toList();
  }

  Future<InstructorOfferings> fetchInstructorOfferings(String email) async {
    final encoded = Uri.encodeComponent(email.trim().toLowerCase());
    final data = await _client.requestJson('/api/instructors/$encoded/offerings');
    return InstructorOfferings.fromJson(data);
  }

  Future<List<StudentSummary>> searchStudents(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final data = await _client.requestJson(
      '/api/students/search',
      query: {'q': q},
    );
    final list = data['results'] as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().map(StudentSummary.fromJson).toList();
  }

  Future<StudentOfferings> fetchStudentOfferings(String kerberos) async {
    final encoded = Uri.encodeComponent(kerberos.trim().toLowerCase());
    final data = await _client.requestJson('/api/students/$encoded/offerings');
    return StudentOfferings.fromJson(data);
  }
}
