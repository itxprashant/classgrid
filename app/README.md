# ClassGrid Android app

Flutter client for [ClassGrid](../README.md). Feature parity with the web SPA; uses the same Express backend.

```bash
flutter pub get
flutter run                                    # production API
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # emulator → local server
flutter run -d linux                           # desktop login: paste token from browser
flutter analyze && flutter test && flutter build apk --release
```

**Release APK** (hosted on the ClassGrid VM at `https://classgrid.devclub.in/app/classgrid.apk`, same URL as the web “Get APK” button and `GET /api/app/version`):

```bash
./scripts/release-android-apk.sh              # stage + deploy existing release APK
./scripts/release-android-apk.sh --build      # flutter build apk --release, then deploy
```

Bump `version:` in `app/pubspec.yaml` before each release. The script stages `dist/app/classgrid.apk`, updates `server/data/android-version.json` and `src/pages/Generator.jsx`, then runs `./deploy.sh --api`, `--apk`, and `--static`. Use `--no-deploy` to skip deploy; `--build` to rebuild the APK first. The app calls `GET /api/app/version` at startup and blocks until the installed build is current.

Local dev without the check: `flutter run --dart-define=SKIP_VERSION_CHECK=true`.

Linux desktop: if the project has no `linux/` folder yet, run `flutter create --platforms=linux .` from `app/`. IITD login opens the browser, then paste the token from the success page (no `classgrid://` handler). Requires API with `GET /auth/login?app=1&desktop=1` (deploy `./deploy.sh --api` for prod).

**Attendance** (drawer → Tools): mark present/absent/excused per planned session; syncs via `GET/PUT/PATCH /api/me/attendance` when signed in. Requires migration `007_user_course_attendance.sql` on Postgres (`./deploy.sh --api` does not run migrations).

**CGPA calculator** (drawer → Tools): compute semester SGPA and projected CGPA from 10-point grades; import credits from the plan; prior CGPA/credits and rows persist in SharedPreferences (`cg_prior_cgpa`, `cg_prior_credits`, `cg_semester_rows`). Client-only — no API.

See the root [README](../README.md) and [AGENTS.md § Mobile app](../AGENTS.md#mobile-app-app) for auth, catalog caching, and deploy notes.
