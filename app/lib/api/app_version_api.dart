import '../models/app_version_info.dart';
import 'api_client.dart';

class AppVersionApi {
  AppVersionApi(this._client);
  final ApiClient _client;

  Future<AppVersionInfo?> fetchAndroidRequirement() async {
    final data = await _client.requestJson('/api/app/version');
    final android = data['android'];
    if (android is! Map) return null;
    return AppVersionInfo.fromJson(Map<String, dynamic>.from(android));
  }
}
