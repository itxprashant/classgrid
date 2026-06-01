# ClassGrid Android app

Flutter client for [ClassGrid](../README.md). Feature parity with the web SPA; uses the same Express backend.

```bash
flutter pub get
flutter run                                    # production API
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # emulator → local server
flutter run -d linux                           # desktop login: paste token from browser
flutter analyze && flutter test && flutter build apk --release
```

**Sideload APK on Google Drive** (same link as the web “Download APK” button): from repo root, with [gdrive](https://github.com/glotlabs/gdrive) logged in (`gdrive account list`):

```bash
./scripts/release-android-apk.sh              # upload existing APK
./scripts/release-android-apk.sh --build      # flutter build apk --release, then upload
```

Bump `version:` in `app/pubspec.yaml` before each release, then `./scripts/release-android-apk.sh` (uploads Drive APK, bumps `android-version.json` + `Generator.jsx`, runs `./deploy.sh --api` and `./deploy.sh --static`). Use `--no-deploy` to skip deploy; `--build` to rebuild the APK first. The app calls `GET /api/app/version` at startup and blocks until the installed build is current.

Local dev without the check: `flutter run --dart-define=SKIP_VERSION_CHECK=true`. The upload is named `ClassGrid_<version>.apk` (version name before `+`, e.g. `ClassGrid_1.0.0.apk`). Override the Drive file with `GOOGLE_DRIVE_APK_FILE_ID=…` if needed.

Linux desktop: if the project has no `linux/` folder yet, run `flutter create --platforms=linux .` from `app/`. IITD login opens the browser, then paste the token from the success page (no `classgrid://` handler). Requires API with `GET /auth/login?app=1&desktop=1` (deploy `./deploy.sh --api` for prod).

See the root [README](../README.md) and [AGENTS.md § Mobile app](../AGENTS.md#mobile-app-app) for auth, catalog caching, and deploy notes.
