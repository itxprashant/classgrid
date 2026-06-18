import 'api_client.dart';

class FeedbackApi {
  FeedbackApi(this._client);
  final ApiClient _client;

  /// POST /api/feedback — login optional.
  Future<Map<String, dynamic>> submit({
    required String message,
    String category = 'feature',
    String? pageContext,
    String client = 'android',
  }) async {
    return _client.requestJson(
      '/api/feedback',
      method: 'POST',
      body: {
        'message': message,
        'category': category,
        if (pageContext != null && pageContext.isNotEmpty) 'pageContext': pageContext,
        'client': client,
      },
    );
  }
}
