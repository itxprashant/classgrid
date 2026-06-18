import '../models/course_policy.dart';
import 'api_client.dart';

class CoursePolicyResponse {
  const CoursePolicyResponse({
    required this.semesterCode,
    required this.courseCode,
    this.policy,
  });

  final String semesterCode;
  final String courseCode;
  final CoursePolicy? policy;
}

class CoursePolicyApi {
  CoursePolicyApi(this._client);
  final ApiClient _client;

  /// `GET /api/courses/:code/policy` — enrolled students only.
  Future<CoursePolicyResponse> fetchPolicy(String courseCode) async {
    final data = await _client.requestJson(
      '/api/courses/${Uri.encodeComponent(courseCode)}/policy',
    );
    final policyRaw = data['policy'];
    return CoursePolicyResponse(
      semesterCode: (data['semesterCode'] ?? '').toString(),
      courseCode: (data['courseCode'] ?? courseCode).toString(),
      policy: policyRaw is Map
          ? CoursePolicy.fromJson(Map<String, dynamic>.from(policyRaw))
          : null,
    );
  }

  /// `PUT /api/courses/:code/policy` — enrolled students only.
  Future<CoursePolicy> savePolicy(String courseCode, Map<String, dynamic> payload) async {
    final data = await _client.requestJson(
      '/api/courses/${Uri.encodeComponent(courseCode)}/policy',
      method: 'PUT',
      body: payload,
    );
    return CoursePolicy.fromJson(Map<String, dynamic>.from(data['policy']));
  }
}
