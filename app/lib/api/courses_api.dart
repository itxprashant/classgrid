import '../api/api_client.dart';
import '../models/enrolled_student.dart';

class CoursesApi {
  CoursesApi(this._client);

  final ApiClient _client;

  /// `GET /api/courses/:courseCode/students` — enrolled students for one course.
  Future<CourseRoster> fetchCourseStudents(String courseCode) async {
    final code = courseCode.trim().toUpperCase();
    final data = await _client.requestJson('/courses/$code/students');
    return CourseRoster.fromJson(data);
  }
}
