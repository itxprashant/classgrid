import '../models/app_version_info.dart';
import 'api_client.dart';

class AppVersionApi {
  AppVersionApi(this._client);
  final ApiClient _client;

  Future<AppReleaseStatus?> fetchAndroidReleaseStatus() async {
    final data = await _client.requestJson('/api/app/version');
    final android = data['android'];
    if (android is! Map) return null;
    return AppReleaseStatus.fromJson(Map<String, dynamic>.from(android));
  }

  /// Legacy helper — returns latest requirement info.
  Future<AppVersionInfo?> fetchAndroidRequirement() async {
    final status = await fetchAndroidReleaseStatus();
    return status?.latest;
  }

  Future<AppChangelogPage> fetchChangelog({
    String platform = 'android',
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client.requestJson(
      '/api/app/changelog?platform=$platform&limit=$limit&offset=$offset',
    );
    return AppChangelogPage.fromJson(Map<String, dynamic>.from(data));
  }
}
