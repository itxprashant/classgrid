# ClassGrid Android app

Flutter client for [ClassGrid](../README.md). Feature parity with the web SPA; uses the same Express backend.

```bash
flutter pub get
flutter run                                    # production API
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # emulator → local server
flutter run -d linux                           # desktop login: paste token from browser
flutter analyze && flutter test && flutter build apk --release
```


Linux desktop: if the project has no `linux/` folder yet, run `flutter create --platforms=linux .` from `app/`. IITD login opens the browser, then paste the token from the success page (no `classgrid://` handler). Requires API with `GET /auth/login?app=1&desktop=1` (deploy `./deploy.sh --api` for prod).

See the root [README](../README.md) and [AGENTS.md § Mobile app](../AGENTS.md#mobile-app-app) for auth, catalog caching, and deploy notes.
