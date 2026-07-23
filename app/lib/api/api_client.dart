import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// Error thrown by API wrappers, carrying the HTTP status and the backend's
/// `error` code when present (mirrors the web `apiError` helper).
class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;

  ApiException(this.message, {this.status, this.code});

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Thin HTTP layer over the ClassGrid API.
///
/// Authentication uses the same `cg_session` JWT the web app stores as an
/// httpOnly cookie. After browser login the backend deep-links the token into
/// the app; here it is persisted and replayed as a `Cookie` header on every
/// request, which the cookie-only backend accepts unchanged.
class ApiClient {
  ApiClient._(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _sessionToken;

  static const _kCookieKey = 'cg_session_cookie';

  static Future<ApiClient> create() async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      // We handle non-2xx ourselves so 304/4xx don't throw before inspection.
      validateStatus: (s) => s != null && s < 500,
    ));
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
    );
    final client = ApiClient._(dio, storage);
    client._sessionToken = await storage.read(key: _kCookieKey);
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (client._sessionToken != null && client._sessionToken!.isNotEmpty) {
          options.headers['Cookie'] =
              '${AppConfig.sessionCookie}=${client._sessionToken}';
        }
        options.headers['X-ClassGrid-Client'] ??= 'android';
        handler.next(options);
      },
    ));
    return client;
  }

  bool get hasSession => (_sessionToken?.isNotEmpty ?? false);

  Future<void> setSessionToken(String? token) async {
    _sessionToken = token;
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _kCookieKey);
    } else {
      await _storage.write(key: _kCookieKey, value: token);
    }
  }

  Future<void> clearSession() => setSessionToken(null);

  Dio get dio => _dio;

  /// Performs a request and returns the decoded JSON map, throwing
  /// [ApiException] on error responses (and clearing the session on 401).
  Future<Map<String, dynamic>> requestJson(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final res = await _send(path, method: method, query: query, body: body);
    final data = res.data;
    if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    }
    _throwFor(res);
  }

  Future<Response<dynamic>> _send(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? query,
    Object? body,
  }) {
    return _dio.request<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: Options(method: method, contentType: Headers.jsonContentType),
    );
  }

  Never _throwFor(Response<dynamic> res) {
    final status = res.statusCode;
    String? code;
    String message = 'Request failed (HTTP $status)';
    final data = res.data;
    if (data is Map && data['error'] is String) {
      code = data['error'] as String;
      message = code;
    }
    if (status == 401) {
      // Stored session is no longer valid; drop it so the UI prompts re-login.
      clearSession();
      message = 'not_authenticated';
      code ??= 'not_authenticated';
    } else if (status == 414) {
      message = 'Request URI too long';
    } else if (status == 503) {
      message = 'database_unavailable';
      code ??= 'database_unavailable';
    }
    throw ApiException(message, status: status, code: code);
  }
}
