import 'package:flutter/foundation.dart';

/// App-wide configuration. The API base can be overridden at build time:
///   flutter run --dart-define=API_BASE=http://10.0.2.2:4000
/// (10.0.2.2 is the Android emulator alias for the host machine's localhost.)
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://classgrid.devclub.in',
  );

  /// The session cookie name set by the backend after OAuth.
  static const String sessionCookie = 'cg_session';

  /// Deep-link scheme registered in AndroidManifest / iOS Info.plist.
  static const String appLinkScheme = 'classgrid';

  /// Linux/Windows have no registered `classgrid://` handler — use paste flow.
  static bool get usesDesktopLogin =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Opens ClassGrid in the system browser. Mobile: deep link callback.
  /// Desktop: HTML page with a token to paste into the app.
  static String get browserLoginUrl => usesDesktopLogin
      ? '$apiBase/auth/login?app=1&desktop=1'
      : '$apiBase/auth/login?app=1';

  /// Skip GET /api/app/version (local dev only).
  static const bool skipVersionCheck = bool.fromEnvironment(
    'SKIP_VERSION_CHECK',
    defaultValue: false,
  );
}
