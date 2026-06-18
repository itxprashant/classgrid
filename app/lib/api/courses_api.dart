import '../api/api_client.dart';
import '../models/enrolled_student.dart';

class CoursesApi {
  CoursesApi(this._client);

  final ApiClient _client;

  /// `GET /api/courses/:courseCode/students` — enrolled students for one course.
  /// Pass [semesterCode] (e.g. `2502`) for a historical offering roster.
  Future<CourseRoster> fetchCourseStudents(String courseCode, {String? semesterCode}) async {
    final code = courseCode.trim().toUpperCase();
    final sem = semesterCode?.trim();
    final data = await _client.requestJson(
      '/api/courses/$code/students',
      query: sem != null && sem.isNotEmpty ? {'semester': sem} : null,
    );
    return CourseRoster.fromJson(data);
  }
}
