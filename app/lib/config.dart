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

  /// Opens ClassGrid in the system browser; after OAuth the backend redirects
  /// back to [appLinkScheme]://auth/callback?token=….
  static String get browserLoginUrl => '$apiBase/auth/login?app=1';
}
