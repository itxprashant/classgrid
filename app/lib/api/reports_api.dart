import 'api_client.dart';

class ReportsApi {
  ReportsApi(this._client);
  final ApiClient _client;

  /// POST /api/reports — requires session.
  Future<Map<String, dynamic>> submit({
    required String targetKind,
    required String targetId,
    required String reason,
    String details = '',
    String? pageContext,
    String? label,
  }) async {
    return _client.requestJson(
      '/api/reports',
      method: 'POST',
      body: {
        'targetKind': targetKind,
        'targetId': targetId,
        'reason': reason,
        'details': details,
        if (pageContext != null && pageContext.isNotEmpty) 'pageContext': pageContext,
        if (label != null && label.isNotEmpty) 'label': label,
      },
    );
  }
}
