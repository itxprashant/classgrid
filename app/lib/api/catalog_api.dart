import '../models/course.dart';
import 'api_client.dart';

class CatalogApi {
  CatalogApi(this._client);
  final ApiClient _client;

  /// Fetches the full course catalog from `GET /api/catalog`.
  Future<List<Course>> fetchCatalog() async {
    final data = await _client.requestJson('/api/catalog');
    final raw = data['courses'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Course.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
