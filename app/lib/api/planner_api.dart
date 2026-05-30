import '../models/plan.dart';
import 'api_client.dart';

class PlannerApi {
  PlannerApi(this._client);
  final ApiClient _client;

  /// `GET /api/me/courses` — registered course codes for auto-fetch.
  Future<List<String>> fetchEnrolledCourses() async {
    final data = await _client.requestJson('/api/me/courses');
    final raw = data['courses'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// `GET /api/me/plan` — the saved plan.
  Future<Plan> fetchPlan() async {
    final data = await _client.requestJson('/api/me/plan');
    return Plan.fromJson(data);
  }

  /// `PUT /api/me/plan` — full replace.
  Future<Plan> savePlan(Plan plan) async {
    final data = await _client.requestJson(
      '/api/me/plan',
      method: 'PUT',
      body: plan.toJson(),
    );
    return Plan.fromJson(data);
  }
}
