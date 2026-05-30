# ClassGrid

A timetable planner for IIT Delhi students — **web app** (React) plus an **Android app** (Flutter). Both talk to the same backend for login, plan sync, calendar events, and room occupancy.

Live site: [classgrid.devclub.in](https://classgrid.devclub.in)

### Key Features

- **Sign in with IITD:** OAuth via `auth.devclub.in` pulls registered courses onto the planner (web and Android).
- **Interactive Timetable Grid:** Weekly schedule with color-coded slots and clash detection.
- **Venue Synchronization:** Lecture halls updated from the latest semester allotment data.
- **Manual Customization:** Add courses and pick tutorial/lab timings.
- **Empty Lecture Halls:** See free LH rooms at a chosen date/time.
- **Calendar:** Shared course events (quizzes, deadlines) and private personal events.
- **Export:** Download the plan as `.ics` (web and Android); PNG export on web only.

## Repository structure

Monorepo: React web client, Express API, Flutter Android app, and semester tooling.

```
classgrid/
├── README.md              # You are here
├── AGENTS.md              # Contributor / operator guide (APIs, deploy, mobile)
├── package.json           # Web app (Create React App)
├── public/                # CRA static assets
├── src/                   # Web SPA source + generated JSON consumed at build time
├── server/                # Express API (OAuth, Postgres)
├── app/                   # Flutter Android client
├── scripts/               # Semester refresh (CSV → JSON, venues, enrollments)
├── data/                  # Semester inputs (CSV, room-allotment PDF) — see data/README.md
├── docs/                  # Design system and extended documentation
├── assets/                # Shared branding (app icon source)
├── deploy/                # nginx reference config (production uses deploy.sh inline)
├── deploy.sh              # Production deploy script (web + API)
└── docker-compose.db.yml  # Postgres stack for calendar / plans / room markings
```

| Path | What it is |
| --- | --- |
| [src/](src/) | React SPA — routes in [src/App.js](src/App.js). |
| [server/](server/) | Node/Express backend (OAuth + Postgres). |
| [app/](app/) | Flutter Android client. |
| [scripts/](scripts/) | Data refresh scripts. |
| [data/](data/) | Semester source files (`Courses_Offered.csv`, room PDF). |
| [docs/DESIGN.md](docs/DESIGN.md) | UI tokens, typography, visual rules. |
| [deploy.sh](deploy.sh) | Build and deploy web + API. |

See [AGENTS.md](AGENTS.md) for APIs, persistence, and mobile details.

## Getting Started

### Web (CRA)

```bash
npm install
npm start
```

Open [http://localhost:3000](http://localhost:3000). The dev server proxies `/auth/*` and `/api/*` to the backend on port 4000.

### Backend (optional for local dev)

Required for **Login with IITD**, plan sync, calendar writes, and room markings. Guest planner browsing works without it.

```bash
cd server
cp .env.example .env
# fill in OIDC_CLIENT_ID, OIDC_CLIENT_SECRET, SESSION_SECRET, DATABASE_URL, etc.
npm install
npm start                 # http://localhost:4000
```

Register a localhost redirect URI with the IdP (e.g. `http://localhost:4000/auth/callback`).

### Android app (Flutter)

Native client in [app/](app/) with bottom tabs for **Plan**, **Courses**, **Empty halls**, and **Calendar**. Business logic in `app/lib/core/` mirrors the web utilities; the course catalog is fetched from `GET /api/catalog` (not bundled in the APK).

**Requirements:** Flutter 3 / Dart 3.10+ ([install Flutter](https://docs.flutter.dev/get-started/install)).

```bash
cd app
flutter pub get
flutter run                    # production API (classgrid.devclub.in)
```

**Emulator + local backend** (with `server/` running on the host):

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:4000
```

On a physical device, use your machine's LAN IP instead of `10.0.2.2`.

**Login:** tap the profile button → IITD OAuth opens in the system browser → return to the app via the `classgrid://auth/callback` deep link. Same session as the website.

**Build release APK:**

```bash
flutter analyze
flutter test
flutter build apk --release
```

The mobile app is **not** deployed by `./deploy.sh` — ship the APK via sideload or Play Console. Catalog updates follow the backend deploy flow in [Course catalog](#course-catalog).

More detail (auth flow, state, parity gaps): [AGENTS.md § Mobile app](AGENTS.md#mobile-app-app).

## Production deployment

Deploys to a remote Linux host (nginx + systemd) via [deploy.sh](deploy.sh). **No host or SSH key is hardcoded** — copy the example config first:

```bash
cp deploy.env.example deploy.env
# edit deploy.env: DEPLOY_HOST, DEPLOY_USER, SSH_IDENTITY, DEPLOY_DOMAIN
```

Then:

```bash
./deploy.sh             # build + rsync SPA + rsync API + restart service
./deploy.sh --setup     # first-time: nginx + certbot + systemd, then deploy
./deploy.sh --static    # only the SPA bundle (no API)
./deploy.sh --api       # only the backend (no rebuild)
```

Production URLs depend on your `DEPLOY_DOMAIN` (live site: [classgrid.devclub.in](https://classgrid.devclub.in)). Backend secrets live in `/etc/classgrid/api.env` on the server (gitignored, hand-edited).

## Course catalog

The offered-courses list lives in [src/courses.json](src/courses.json). It is built from IITD’s [`data/Courses_Offered.csv`](data/Courses_Offered.csv) plus venue fields from the room-allotment PDF ([scripts/csv_to_json.py](scripts/csv_to_json.py), then [scripts/sync_venues.py](scripts/sync_venues.py)).

Three clients read that file differently:

| Client | How it gets the catalog | When it updates |
| --- | --- | --- |
| **Web SPA** | Bundled at build time — CRA imports `src/courses.json` into the JS bundle | After you rebuild and deploy the static site |
| **Backend API** | Reads a JSON file from disk (`CATALOG_PATH`) and serves it at `GET /api/catalog` | After the file on disk changes **and** the API process restarts |
| **Android app** | Downloads `GET /api/catalog` on launch (cached offline in SharedPreferences) | After the backend serves a new catalog; pull-to-refresh / next cold start |

**Local dev:** with no `CATALOG_PATH` set, the API defaults to `src/courses.json` in the repo ([server/src/config.js](server/src/config.js)). Restart `npm start` in `server/` after regenerating the file.

**Production:** `deploy.sh` rsyncs `src/courses.json` to `data/courses.json` on the API host. Production `api.env` sets `CATALOG_PATH` to that path. The catalog router loads the file once at startup ([server/src/catalog.js](server/src/catalog.js)), so uploading a new JSON without restarting the service will not change live responses.

To publish an updated catalog:

```bash
# 1. Regenerate src/courses.json (see “Updating for a New Semester” below)
python3 scripts/csv_to_json.py
python3 scripts/sync_venues.py

# 2. Web — rebundle into the SPA
./deploy.sh --static

# 3. Backend + Android — upload JSON and restart classgrid-api
./deploy.sh --api
```

Or run `./deploy.sh` to do both. Override the upload source if your catalog file lives elsewhere:

```bash
CATALOG_DATA_SRC=/path/to/courses.json ./deploy.sh --api
```

Cheap revalidation without downloading the full payload: `GET /api/catalog/meta` returns `{ semesterCode, count, etag }`.

## Updating for a New Semester

Refresh the data files below from the repo root, then deploy (see [Course catalog](#course-catalog) for what each deploy target picks up).

1. **Update the course list** ([src/courses.json](src/courses.json))
  - Download the new `Courses_Offered.csv` from the IITD Timetable site into [`data/`](data/).
  - Regenerate the JSON:
    ```bash
    python3 scripts/csv_to_json.py
    ```
2. **Update venue / lecture-hall allotment**
  - Find the new "Room Allotment Chart" PDF URL.
  - Edit `PDF_URL` in [scripts/sync_venues.py](scripts/sync_venues.py).
  - Run:
    ```bash
    python3 scripts/sync_venues.py
    ```
3. **Update student course registrations** ([src/studentCourses.json](src/studentCourses.json) + [src/courseStudents.json](src/courseStudents.json))
  - Edit `SEMESTER_PREFIX` in [scripts/fetch_student_courses.js](scripts/fetch_student_courses.js) (e.g. `'2601-'` for Sem 2601).
  - Run:
    ```bash
    node scripts/fetch_student_courses.js
    ```
  - These files are large (multi-MB) when populated. The repo ships **stubs** (a single sample student) so the bundle stays small. Don't commit the regenerated blobs unless you are intentionally refreshing semester data.
4. **Update semester labels in the planner**
  - Web: in [src/pages/Generator.jsx](src/pages/Generator.jsx) bump `SEMESTER_LABEL`, `SEMESTER_START`, and `SEMESTER_END`.
  - Android: match the same window in [app/lib/core/semester_schedule.dart](app/lib/core/semester_schedule.dart) and [app/lib/core/ics.dart](app/lib/core/ics.dart).
5. **Deploy**
  - **Web catalog** (bundled JSON): `./deploy.sh --static`
  - **Backend catalog** (`GET /api/catalog` for Android) **+ enrollment data**: `./deploy.sh --api` — uploads `src/courses.json` and restarts the API. Override paths if needed:
    ```bash
    CATALOG_DATA_SRC=/path/to/courses.json \
    STUDENT_DATA_SRC=/path/to/populated/studentCourses.json \
    ./deploy.sh --api
    ```
  - **Both:** `./deploy.sh`

