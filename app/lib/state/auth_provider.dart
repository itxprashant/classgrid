import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/user.dart';

/// Holds auth state. Calls `GET /api/me` on startup; login opens the ClassGrid
/// site in the system browser and completes via a deep link back into the app.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._client);

  final ApiClient _client;
  AppUser? _user;
  bool _loading = true;
  bool _awaitingBrowserLogin = false;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get awaitingBrowserLogin => _awaitingBrowserLogin;
  ApiClient get client => _client;

  Future<void> init() async {
    await refresh();
  }

  /// Loads `GET /api/me`. Clears the user on any failure (e.g. 401).
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    if (!_client.hasSession) {
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await _client.requestJson('/api/me');
      _user = AppUser.fromJson(data);
    } catch (_) {
      _user = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Opens ClassGrid in the external browser. OAuth completes on the site;
  /// the backend redirects to `classgrid://auth/callback?token=…`.
  Future<bool> startBrowserLogin() async {
    final url = Uri.parse(AppConfig.browserLoginUrl);
    _awaitingBrowserLogin = true;
    notifyListeners();
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _awaitingBrowserLogin = false;
      notifyListeners();
    }
    return opened;
  }

  /// Called from [AuthDeepLinkListener] when the app receives the OAuth callback.
  Future<void> handleAuthCallback(Uri uri) async {
    if (!_isAuthCallback(uri)) return;
    _awaitingBrowserLogin = false;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    await completeLogin(token);
  }

  bool _isAuthCallback(Uri uri) =>
      uri.scheme == AppConfig.appLinkScheme &&
      uri.host == 'auth' &&
      uri.path == '/callback';

  Future<void> completeLogin(String sessionToken) async {
    await _client.setSessionToken(sessionToken);
    await refresh();
  }

  Future<void> logout() async {
    try {
      await _client.requestJson('/auth/logout', method: 'POST');
    } catch (_) {
      // Best-effort: clear locally regardless.
    }
    await _client.clearSession();
    _user = null;
    _awaitingBrowserLogin = false;
    notifyListeners();
  }
}
