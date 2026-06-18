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
- **Course & prof history:** Past-semester offerings and instructor search (web **Professors** nav; Android drawer → Prof explorer) after importing [`data/courses_offered_historical/`](data/courses_offered_historical/) via [`scripts/db/import_historical_catalog.js`](scripts/db/import_historical_catalog.js).

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

Native client in [app/](app/) with bottom tabs for **Plan**, **Courses**, **Rooms**, and **Calendar** (empty-hall finder opened from Rooms). Business logic in `app/lib/core/` mirrors the web utilities; the course catalog is fetched from `GET /api/catalog` (not bundled in the APK).

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

Deploys to a remote Linux host (nginx + systemd) via [deploy.sh](deploy.sh). SSH uses your **`~/.ssh/config` Host alias** `mydevclub` by default (same as `ssh mydevclub`). Optional [deploy.env.example](deploy.env.example) → `deploy.env` for `DEPLOY_DOMAIN` overrides.

```bash
./deploy.sh             # build + rsync SPA + rsync API + restart service
./deploy.sh --setup     # first-time: nginx + certbot + systemd, then deploy
./deploy.sh --static    # only the SPA bundle (no API)
./deploy.sh --api       # only the backend (no rebuild)
```

Production URLs depend on your `DEPLOY_DOMAIN` (live site: [classgrid.devclub.in](https://classgrid.devclub.in)). Backend secrets live in `/etc/classgrid/api.env` on the server (gitignored, hand-edited).

## Course catalog

The offered-courses list and all semester reference data live in **Postgres**, imported via [`scripts/db/`](scripts/db/) from IITD inputs such as [`data/Courses_Offered.csv`](data/Courses_Offered.csv) and the room-allotment PDF.

All clients fetch from the API (local cache is offline fallback only):

| Client | How it gets semester data | When it updates |
| --- | --- | --- |
| **Web SPA** | `SemesterDataProvider` → `/api/catalog`, `/api/semester/schedule`, `/api/extra-occupied` | After DB refresh + API restart |
| **Backend API** | Postgres via `semesterData.js` (in-memory cache per process) | After import scripts + `./deploy.sh --api` |
| **Android app** | Same endpoints (SharedPreferences cache; catalog sends `If-None-Match`) | After backend update; next cold start |

**Local dev:** set `DATABASE_URL` in `server/.env`, run migrations, then `node scripts/db/seed_from_files.js` (one-time from legacy `src/*.json` stubs).

**Production:** run `./scripts/db/refresh_semester.sh` (or individual importers) against prod `DATABASE_URL`, then `./deploy.sh --api`.

Cheap revalidation without downloading the full catalog: `GET /api/catalog/meta` returns `{ semesterCode, count, etag }`.

## Updating for a New Semester

Full operator guide: **[scripts/README.md](scripts/README.md)** (inputs, each script, prod runbook).

Run from repo root with `DATABASE_URL` pointing at your target database (local or prod via SSH tunnel).

**One-shot orchestrator** (edit semester code and inputs first):

```bash
export DATABASE_URL=postgresql://classgrid:PASSWORD@127.0.0.1:5432/classgrid
./scripts/db/refresh_semester.sh 2602
./deploy.sh --api   # prod: restart API after DB writes
```

**Step by step:**

1. **Academic calendar** — edit [`data/academic_calendar.json`](data/academic_calendar.json), then:
   ```bash
   node scripts/db/import_academic_calendar.js
   ```
2. **Course catalog** — download `Courses_Offered.csv` into [`data/`](data/), then:
   ```bash
   node scripts/db/import_catalog.js --semester 2602 --csv data/Courses_Offered.csv
   ```
3. **Venue / lecture-hall allotment** — set `ROOM_ALLOTMENT_PDF_URL` (see [`scripts/extract_venue_map.py`](scripts/extract_venue_map.py)), then:
   ```bash
   node scripts/db/sync_venues.js --semester 2602
   ```
4. **Student enrollments + rosters** — LDAP prefix defaults to `{semester}-`; run:
   ```bash
   node scripts/db/import_student_data.js --semester 2602
   ```
5. **Extra occupied overlay** — edit [`data/extra_occupied.json`](data/extra_occupied.json), then:
   ```bash
   node scripts/db/import_extra_occupied.js --semester 2602
   ```
6. **Activate semester** (exactly one `is_active` row):
   ```bash
   node scripts/db/activate_semester.js --semester 2602
   ./deploy.sh --api
   ```

**First-time migration from legacy JSON files:**

```bash
source /etc/classgrid/db.env && /opt/classgrid-db/migrate.sh   # prod
node scripts/db/seed_from_files.js
./deploy.sh --api
```

Legacy `src/*.json` stubs are only for one-time `seed_from_files.js`; use [`scripts/db/`](scripts/db/) for all semester refreshes.

