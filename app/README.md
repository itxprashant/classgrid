# ClassGrid Android app

Flutter client for [ClassGrid](../README.md). Feature parity with the web SPA; uses the same Express backend.

```bash
flutter pub get
flutter run                                    # production API
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # emulator → local server
flutter analyze && flutter test && flutter build apk --release
```

See the root [README](../README.md) and [AGENTS.md § Mobile app](../AGENTS.md#mobile-app-app) for auth, catalog caching, and deploy notes.
