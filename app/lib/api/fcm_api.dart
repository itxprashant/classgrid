import 'api_client.dart';

/// Registers the device FCM token with `POST /api/me/fcm-token`.
class FcmApi {
  FcmApi(this._client);

  final ApiClient _client;

  Future<void> registerToken(String token, {String platform = 'android'}) async {
    await _client.requestJson(
      '/api/me/fcm-token',
      method: 'POST',
      body: {
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<void> deleteToken(String token) async {
    await _client.requestJson(
      '/api/me/fcm-token',
      method: 'DELETE',
      body: {'token': token},
    );
  }
}
