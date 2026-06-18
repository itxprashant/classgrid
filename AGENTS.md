# AGENTS.md

Operational guide for AI agents (and humans) working on this repo. Read this
before making non-trivial edits. The user-facing intro lives in
[README.md](README.md); design rationale lives in [DESIGN.md](docs/DESIGN.md).

## What this is

A React SPA (**ClassGrid**) that lets IIT Delhi students plan a weekly
timetable from the offered-courses catalog, plus a small Node/Express
backend that owns IITD OAuth login, per-user APIs, and Postgres-backed
persistence for plans, shared course calendar events, personal calendar
events, manual room occupancy, and semester reference data (catalog,
enrollments, rosters, academic calendar). Web and Flutter fetch semester
data from Postgres-backed APIs at boot; local cache is offline fallback only.
Login, course lookup, planner sync, and calendar/room writes go through the backend.
Guests keep planner state in `localStorage`; signed-in users sync the plan
to Postgres. A **Flutter** mobile client lives in `app/` and talks to the same
backend (see [Mobile app](#mobile-app-app) below).

Routes (declared in [src/App.js](src/App.js)):

- `/` → [src/pages/Generator.jsx](src/pages/Generator.jsx) — main planner.
  Add-course modal, timetable grid, tutorial/lab picking, clash detection,
  ICS + PNG export. **Auto-fetch** (OAuth, login required) loads registered
  courses from `/api/me/courses` and **replaces** the plan in UI + DB after
  a confirmation dialog. Signed-in users load/save the plan via
  `GET/PUT /api/me/plan` (debounced save on edit). **Holidays & timetable
  changes** modal via [AcademicCalendarButton](src/components/AcademicCalendar/AcademicCalendarButton.jsx).
- `/course-explorer` → [src/pages/CourseExplorer.jsx](src/pages/CourseExplorer.jsx)
  — paginated list from `GET /api/catalog/explorer`: every course code on record
  (active semester + latest archived offering per code). Rows for courses not
  offered this semester show a **Not offered** badge.
- `/course/:courseCode` → [src/pages/CourseDetails.jsx](src/pages/CourseDetails.jsx)
  — single course view with enrolled-students roster link (offered courses only),
  **course policy** ([CoursePolicySection.jsx](src/components/CoursePolicy/CoursePolicySection.jsx);
  enrolled students only; inline edit panel for marking/attendance/audit notes with
  attribution), and **past offerings** history. Resolves from active catalog →
  explorer catalog → `GET /api/courses/:code/offerings`; shows **Not offered this sem**
  when `offeredThisSemester === false`.
- `/professors` → [src/pages/ProfessorExplorer.jsx](src/pages/ProfessorExplorer.jsx)
  — search instructors across archived semesters.
- `/professor/:email` → [src/pages/ProfessorDetail.jsx](src/pages/ProfessorDetail.jsx)
  — courses taught by one instructor email.
- `/students` → [src/pages/StudentExplorer.jsx](src/pages/StudentExplorer.jsx)
  — search students by name or kerberos across imported enrollment data.
- `/student/:kerberos` → [src/pages/StudentDetail.jsx](src/pages/StudentDetail.jsx)
  — registered courses (past and current), branch/entry year from kerberos, optional hostel from `students` table.
- `/rooms` → [src/pages/RoomSchedules.jsx](src/pages/RoomSchedules.jsx) —
  browse all campus rooms from the catalog (`lectureHall` + extra-occupied API);
  search by name and filter by building prefix (e.g. LH). Primary entry to **Empty halls**
  via button → `/empty-halls`.
- `/rooms/:roomSlug` → [src/pages/RoomDetail.jsx](src/pages/RoomDetail.jsx) —
  per-room weekly schedule as a list or calendar grid; data from
  [src/utils/roomSchedule.js](src/utils/roomSchedule.js).
- `/empty-halls` → [src/pages/EmptyLectureHalls.jsx](src/pages/EmptyLectureHalls.jsx)
  — free campus rooms at a chosen **date and time** vs the live timetable
  (lecture, tutorial, and lab slots; all `lectureHall` tokens, not LH-only).
  Logic in [src/utils/emptyHalls.js](src/utils/emptyHalls.js). Green = free;
  red = manually marked occupied (Postgres). Room name → `/rooms/:slug`;
  **Mark** / **Details** for manual occupancy. Legacy overlay from
  `GET /api/extra-occupied`.
- `/calendar` → [src/pages/MyCalendar.jsx](src/pages/MyCalendar.jsx) —
  monthly grid for **shared course events** (quizzes, deadlines, …) and
  **personal events** (private per user). Shared events: Postgres
  `course_events` via `/api/events`. Personal events: `personal_events`
  via `/api/me/events`. Click a day → picker with **Course event** or
  **Personal event**. Optional **Show classes** overlay from
  planner `localStorage`. Academic day markers from `getAcademicDay()`;
  institute calendar via **Holidays & timetable changes** modal on this page too.
- `/my-calendar` → redirect to `/calendar`.
- `/feedback` → [src/pages/Feedback.jsx](src/pages/Feedback.jsx) —
  feature suggestions (`POST /api/feedback`; login optional). Footer and user
  menu link here. Logged-in users can also file a generic content report
  (`POST /api/reports`, `targetKind: other`). Contextual **Report** actions on
  shared calendar events, course policy, and manual room markings call the same
  reports API.
- `/admin` → web-only admin panel ([src/pages/admin/](src/pages/admin/)) —
  **not linked from public nav**. Requires IITD login + kerberos in
  `ADMIN_KERBERSES` (see [server/src/adminAuth.js](server/src/adminAuth.js)).
  Separate chrome (no `Navbar`/`Footer`). Tabs: **Overview** (health + inbox
  counts), **Feedback** (read-only `app_feedback` table), **Reports** (triage
  `content_reports`: dismiss/review, or remove reported UGC and mark `actioned`).
  Client gate: `GET /api/admin/me`; data via [adminApi.js](src/utils/adminApi.js).

`Navbar` links: Plan · **Explore** (dropdown: Courses · Professors · Students) · Rooms · Calendar (plus IITD login). **Empty halls** is linked from `/rooms` (not a top-level nav item).
`Footer` wraps every public route; `/admin*` uses its own shell without navbar/footer.

## Tech stack

### Frontend (`src/`)
- React 18 + `react-scripts` 5 (Create React App). No TypeScript.
- `react-router-dom` v6 with `BrowserRouter`.
- `html2canvas-pro` for PNG export, `jspdf` is a dependency but unused at
  the moment.
- No state library — `useState`/`useMemo`/`localStorage` for the guest
  planner cache; signed-in planner and calendars fetch from the API. Auth
  state lives in [src/auth/AuthContext.jsx](src/auth/AuthContext.jsx).
  Semester catalog data (active + explorer) loads at boot via
  [SemesterDataContext.jsx](src/data/SemesterDataContext.jsx).
- No CSS framework — hand-authored CSS using design tokens in
  [src/index.css](src/index.css) and shared primitives in
  [src/styles/ui.css](src/styles/ui.css).

### Backend (`server/`)
- Node 18+ / Express 4, CommonJS.
- `pg` — Postgres pool (`DATABASE_URL`) for `user_plans`, `course_events`,
  `personal_events`, and `occupied_rooms`.
- `openid-client` v6 — runs the IITD OAuth 2.0 authorization-code flow with
  mandatory PKCE (S256).
- Stateless sessions: signed JWT cookies (`cg_flow` for the in-flight PKCE
  exchange, `cg_session` for the logged-in user). Auth stays in JWTs; app
  data listed above lives in Postgres.
- `cookie-parser`, `dotenv`. Env loaded from `server/.env` in dev and
  `/etc/classgrid/api.env` in production.

## Production

Live at **https://classgrid.devclub.in** (branded **ClassGrid** in the UI).

Served from an Azure VM (`20.244.42.13`) via nginx:

- **Static SPA** at `/var/www/classgrid/` (rsynced CRA build).
- **Backend** at `127.0.0.1:4500`, run by `classgrid-api.service` (systemd).
  nginx proxies `/auth/*` and `/api/*` to it.
- **Postgres** in Docker (`classgrid-postgres`), bound to `0.0.0.0:5432`.
  Data volume `classgrid-db_classgrid_pgdata`. Compose file and migrations live
  in the repo; runtime layout on the VM is `/opt/classgrid-db/`.

The VM also hosts other sites (`csot.devclub.in`, `csot-low-latency.devclub.in`,
`dhh-ui.itxprashant.app`) as separate vhosts and one app holds port 4000 —
**never modify their nginx configs, systemd units, ports, or `/var/www/*`
paths** when deploying this app. classgrid-api intentionally listens on
`4500` to stay out of their way.

Deploy from repo root:

```bash
./deploy.sh              # build + rsync SPA + rsync API + npm ci + restart service
./deploy.sh --setup      # first-time nginx + certbot + systemd unit, then deploy
./deploy.sh --static     # only the SPA (no API touch)
./deploy.sh --api        # only the backend (no rebuild)
./deploy.sh --apk        # only rsync dist/app/classgrid.apk to the web host
```

Environment overrides (all optional):

| Variable | Default |
|----------|---------|
| `DEPLOY_SSH_HOST` | `mydevclub` (`~/.ssh/config` Host alias; same as `ssh mydevclub`) |
| `DEPLOY_DOMAIN` | `classgrid.devclub.in` |
| `API_PORT` | `4500` (must match `PORT` in `/etc/classgrid/api.env`) |
| `APK_SRC` | `dist/app/classgrid.apk` (deployed to `/var/www/classgrid/app/classgrid.apk` via `./deploy.sh --apk`) |

Legacy explicit SSH (if not using a config Host alias): `DEPLOY_HOST`, `DEPLOY_USER`, `SSH_IDENTITY` — or deprecated `AZURE_HOST`, `AZURE_USER`, `AZURE_KEY`, `DOMAIN`.

Production env files (never commit):

| File | Key vars |
|------|----------|
| `/etc/classgrid/api.env` | `OIDC_*`, `SESSION_SECRET`, `PORT`, `FRONTEND_ORIGIN`, `DATABASE_URL`, `ADMIN_KERBERSES` |
| `/etc/classgrid/db.env` | `POSTGRES_*`, `DATABASE_URL` (for Docker Compose + migrate.sh) |

Server-side layout:

- nginx vhost: `/etc/nginx/sites-available/classgrid` (only file `deploy.sh`
  touches).
- Backend code: `/opt/classgrid-api/` (rsynced from `server/`; the `data/`
  subdir is preserved on rsync via `--exclude data`).
- Postgres compose + migrations: `/opt/classgrid-db/` (rsynced manually or
  copied from repo root `docker-compose.db.yml` and `server/db/` — not part
  of `./deploy.sh` yet).
- Backend secrets: `/etc/classgrid/api.env`, mode 640, owner `root:azureuser`.
  Hand-edited on the VM. Never committed. `--setup` only seeds placeholders
  when the file is absent — it will not overwrite real values. Must include
  `DATABASE_URL=postgresql://classgrid:…@127.0.0.1:5432/classgrid` for Postgres
  APIs (copy from `/etc/classgrid/db.env` on the VM).
- Postgres credentials: `/etc/classgrid/db.env` (same ownership/mode). Used by
  `docker compose -f docker-compose.db.yml --env-file /etc/classgrid/db.env`.
- systemd unit: `/etc/systemd/system/classgrid-api.service`.

TLS is Let's Encrypt via certbot (auto-renewal enabled). DNS for
`classgrid.devclub.in` is Cloudflare-proxied like the other devclub.in sites.

Legacy AWS/Docker deployment has been removed; use [deploy.sh](deploy.sh) only.
Production Postgres is the standalone `docker-compose.db.yml` stack on the VM.

### Postgres

First-time on the VM (already done in prod):

```bash
sudo mkdir -p /opt/classgrid-db /etc/classgrid
# copy docker-compose.db.yml + server/db/ to /opt/classgrid-db/
# seed /etc/classgrid/db.env from server/db/db.env.example
sudo docker compose -f /opt/classgrid-db/docker-compose.db.yml \
  --env-file /etc/classgrid/db.env up -d
source /etc/classgrid/db.env && /opt/classgrid-db/migrate.sh
# append DATABASE_URL from db.env into /etc/classgrid/api.env, restart classgrid-api
```

Migrations: numbered SQL files in [server/db/migrations/](server/db/migrations/),
applied by [server/db/migrate.sh](server/db/migrate.sh) (tracks `schema_migrations`).
Add a new file (`006_….sql`) and re-run `migrate.sh` on the VM — do not edit
applied migrations in place. `./deploy.sh --api` does **not** run migrations.

| Migration | Table | Purpose |
|-----------|--------|---------|
| `001_init.sql` | `course_events` | Shared calendar events per course |
| `002_user_plans.sql` | `user_plans` | Per-kerberos planner (`selected_courses`, `timetable_data` JSONB) |
| `003_occupied_rooms.sql` | `occupied_rooms` | Manual LH occupancy (initial schema) |
| `004_occupied_rooms_by_date.sql` | `occupied_rooms` | Replaces weekly `day_of_week` with `occupancy_date` |
| `005_personal_events.sql` | `personal_events` | Private calendar events per kerberos |
| `006_user_reminders.sql` | `user_reminders` | Per-kerberos class/event reminder subscriptions (mobile) |
| `007_user_course_attendance.sql` | `user_course_attendance` | Per-kerberos attendance counters by course + session kind (mobile) |
| `008_semester_data.sql` | `semesters`, `catalog_courses`, `student_enrollments`, `course_rosters`, `extra_occupied_slots`, `app_release_config` | Semester reference data served via API |
| `009_catalog_instructor_email_idx.sql` | `catalog_courses` | Partial index on `course_data->>'instructorEmail'` for prof explorer search |
| `010_course_policies.sql` | `course_policies` | Per-semester course policy docs (enrolled read/write; actor attribution) |
| `011_feedback_reports.sql` | `app_feedback`, `content_reports` | Feature suggestions (optional auth) + UGC reports (session required; triaged via `/admin`) |
| `012_admin_report_review.sql` | `content_reports` | `reviewed_by_kerberos`, `reviewed_at` audit columns for admin triage |
| `013_students.sql` | `students` | Optional per-kerberos profile overlay (`hostel`; null until populated) + roster kerberos search index |

Azure NSG `myvm-nsg` exposes TCP **5432** publicly for remote admin (DBeaver).
Restrict the rule to your IP when you can. The API connects on `127.0.0.1:5432`.

## Commands

Frontend (run from repo root):

```bash
npm start            # CRA dev server on http://localhost:3000
npm run build        # production build into build/
npm test             # CRA test runner (Jest + RTL). Few tests exist.
./deploy.sh          # build + push SPA and API to production (see Production above)
```

Backend (run from `server/`):

```bash
cp .env.example .env   # OIDC_*, SESSION_SECRET, DATABASE_URL, …
npm install
npm start              # listens on http://localhost:4000 (or PORT in .env)
npm run dev            # same, with `node --watch`
```

Mobile app (run from `app/`; see [Mobile app](#mobile-app-app) for architecture):

```bash
flutter pub get
flutter analyze
flutter test
flutter run                                              # prod API
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # emulator → local server
flutter build apk
```

For local My Calendar against prod Postgres, set in `server/.env`:

```
DATABASE_URL=postgresql://classgrid:PASSWORD@20.244.42.13:5432/classgrid
```

Or run Postgres locally: `docker compose -f docker-compose.db.yml --env-file server/db/db.env.example up -d`
(then point `DATABASE_URL` at `127.0.0.1`).

The CRA dev server has `"proxy": "http://localhost:4000"` in
[package.json](package.json), so `/auth/*` and `/api/*` requests issued from
`localhost:3000` reach the local backend without CORS. A localhost redirect
URI must be registered on the IdP side for end-to-end login on dev (e.g.
`http://localhost:4000/auth/callback`).

Semester data refresh (run from repo root; requires `DATABASE_URL` and Node):

```bash
export DATABASE_URL=postgresql://classgrid:PASSWORD@127.0.0.1:5432/classgrid
./scripts/db/refresh_semester.sh 2602    # full chain for a semester code
node scripts/db/seed_from_files.js       # one-time import from legacy src/*.json
```

See [scripts/README.md](../scripts/README.md) for the per-semester refresh procedure.

## Data model

Semester reference data is stored in Postgres (migration `008_semester_data.sql`) and served via API. Web and Flutter fetch at boot; SharedPreferences / in-memory cache is offline fallback only.

**Postgres tables (semester data):**

| Table | Purpose |
|-------|---------|
| `semesters` | Term metadata, `academic_calendar` JSONB, `is_active`, catalog ETag |
| `catalog_courses` | `(semester_code, course_code)` + full `course_data` JSONB |
| `student_enrollments` | `(semester_code, kerberos, course_code)` |
| `course_rosters` | `(semester_code, course_code, student_kerberos)` + name |
| `students` | `kerberos` PK + optional `hostel` (profile overlay; search uses rosters/enrollments) |
| `extra_occupied_slots` | Legacy overlay slots not in the catalog |
| `app_release_config` | Minimum Android APK version + download URL |

Import via [`scripts/db/`](scripts/db/) (see [README.md](README.md)). Legacy `src/courses.json`, `src/studentCourses.json`, `src/courseStudents.json`, and `src/extra_occupied.json` are seed inputs only — not bundled into clients.

**Course object shape** (in `catalog_courses.course_data`):
  ```jsonc
  {
    "courseCode": "COL106",
    "courseName": "DATA STRUCTURES AND ALGORITHMS",
    "semesterCode": "2502",
    "totalCredits": 5.0,
    "creditStructure": "3.0-1.0-2.0",   // lecture-tutorial-lab credits
    "instructor": "...",
    "instructorEmail": "name@dept.iitd.ac.in",
    "currentStrength": "...",
    "slot": {
      "name": "C",
      "lectureTiming": "21100120023110012002",  // see below
      "lectureTimingStr": "...",
      "tutorialTiming": null,
      "labTiming": null
    },
    "lectureHall": "LH 111, LH 121"
  }
  ```
  Served by `GET /api/catalog` (active semester only; planner, rooms, empty halls).
  **Course explorer** uses `GET /api/catalog/explorer` — same course shape plus
  `offeredThisSemester: true|false` (active rows first, then historical-only codes
  with the latest `catalog_courses` snapshot). Enrollments via `GET /api/me/courses`;
  rosters via `GET /api/courses/:code/students`. Academic calendar via
  `GET /api/semester/schedule`; extra overlay via `GET /api/extra-occupied`.
  **History / prof / student explorer:** `GET /api/semesters`, `GET /api/courses/:code/offerings`,
  `GET /api/instructors/search?q=`, `GET /api/instructors/:email/offerings`,
  `GET /api/students/search?q=`, `GET /api/students/:kerberos/offerings` —
  [`server/src/history.js`](server/src/history.js). Import archived CSVs via
  `node scripts/db/import_historical_catalog.js` from
  [`data/courses_offered_historical/`](data/courses_offered_historical/) — required
  for historical-only codes to appear in the explorer.

### Timing string format

`slot.lectureTiming` / `tutorialTiming` / `labTiming` are comma-separated
9-character chunks: `DHHMMHHMM`.

- `D` — day code: `1`=Mon, `2`=Tue, `3`=Wed, `4`=Thu, `5`=Fri.
- `HHMM` — start time, 24h.
- `HHMM` — end time, 24h.

Parsing helper: `parseTimingStr` in
[src/pages/Generator.jsx](src/pages/Generator.jsx). The internal session
shape used everywhere downstream is
`{ day: 'Monday'..'Friday', start: 'HHMM', end: 'HHMM', location?: string }`.

> Note: [src/pages/EmptyLectureHalls.jsx](src/pages/EmptyLectureHalls.jsx)
> compares the timing `D` (1–5) against `Date.getDay()` (0–6, Sun=0). That
> happens to be consistent for Mon–Fri because the catalog only uses 1–5, but
> watch for it if you extend to weekends.

### Persistence

| Data | Storage | Scope | API / module |
|------|---------|--------|----------------|
| Planner courses + tut/lab slots | `user_plans` (Postgres) + `localStorage` cache | Private per kerberos; guests use `localStorage` only | `GET/PUT /api/me/plan` — [plannerApi.js](src/utils/plannerApi.js), [planner.js](server/src/planner.js) |
| Shared calendar events | `course_events` | Shared per course | `/api/events` — [calendarEventsApi.js](src/utils/calendarEventsApi.js) |
| Personal calendar events | `personal_events` | Private per kerberos | `/api/me/events` — [personalEventsApi.js](src/utils/personalEventsApi.js) |
| Class/event reminders (mobile) | `user_reminders` | Private per kerberos | `GET/POST/PUT/DELETE /api/me/reminders` — [reminders.js](server/src/reminders.js), [reminders_api.dart](app/lib/api/reminders_api.dart) |
| Attendance marks (mobile) | `user_course_attendance` | Private per kerberos | `GET/PUT/PATCH /api/me/attendance` — [attendance.js](server/src/attendance.js), [attendance_api.dart](app/lib/api/attendance_api.dart) |
| Manual room occupancy | `occupied_rooms` | Global read; write attributed to marker | `/api/rooms/occupied` — [occupiedRoomsApi.js](src/utils/occupiedRoomsApi.js) |
| Course policy | `course_policies` | Enrolled students only (active semester) | `GET/PUT /api/courses/:code/policy` — [coursePolicyApi.js](src/utils/coursePolicyApi.js), [coursePolicies.js](server/src/coursePolicies.js), [course_policy_api.dart](app/lib/api/course_policy_api.dart) |
| Feature feedback | `app_feedback` | Optional kerberos attribution | `POST /api/feedback` — [feedbackApi.js](src/utils/feedbackApi.js), [feedback.js](server/src/feedback.js), [feedback_api.dart](app/lib/api/feedback_api.dart) |
| Content reports | `content_reports` | Session required; server-side target snapshot | `POST /api/reports` — [reportsApi.js](src/utils/reportsApi.js), [reports.js](server/src/reports.js), [reports_api.dart](app/lib/api/reports_api.dart); admin triage via `/api/admin/*` |

**Planner (Generator)** — keys synced to `localStorage` on every change:

- `selectedCourses` — array of course summaries on the plan.
- `timetableData` — `{ [courseCode]: { lecture, tutorial, lab } }`.

When logged in, `Generator.jsx` loads `user_plans` on mount, debounces
`PUT /api/me/plan` (~800 ms) on edits, and skips one save after a DB load.
Auto-fetch calls `replaceUserPlan()` → full replace in UI + immediate
`PUT`. Confirmation dialog warns before clearing the current plan.

**Shared course events** — shape (API JSON ↔ `course_events` row):

```jsonc
{
  "id": "uuid",
  "date": "YYYY-MM-DD",
  "courseCode": "COL106",
  "title": "Quiz 2",
  "type": "quiz",           // quiz | deadline | exam | extra-class | presentation | others
  "schedule": "fullday",      // fullday | at | timed | eod
  "time": "HHMM",             // when schedule === "at"
  "start": "HHMM", "end": "HHMM",  // when schedule === "timed"
  "note": "…",
  "createdBy": { "kerberos": "…", "name": "…", "at": "ISO8601" },
  "updatedBy": { "kerberos": "…", "name": "…", "at": "ISO8601" }
}
```

Validation/format helpers: [src/utils/calendarEvents.js](src/utils/calendarEvents.js).
The `loadEvents` / `saveEvents` mutators there are **legacy localStorage** —
My Calendar uses the API, not those.

**Personal events** — same schedule/type fields as shared events, but **no
`courseCode`**. API responses include `"isPersonal": true`. Only the owning
kerberos can read/write via `/api/me/events`.

**Occupied rooms** — manual LH bookings not on the official allotment:

```jsonc
{
  "id": "uuid",
  "room": "LH 121",
  "date": "YYYY-MM-DD",       // occupancy_date — one calendar day only
  "start": "1400", "end": "1800",
  "note": "…",                // optional
  "markedBy": { "kerberos": "…", "name": "…", "at": "ISO8601" }
}
```

Markings apply to a **specific date**, not every week on that weekday.
Delete is limited to the user who created the marking.

**Course policy** — one collaborative doc per `(semester_code, course_code)`;
only students enrolled in that course for the active semester may read or write
(via `student_enrollments`). Web UI on Course Details; mobile on course detail.
Upsert replaces all four text fields; `GET` returns `{ policy: null }` when unset.

```jsonc
{
  "markingScheme": "Midsem 30%, endsem 40%, …",
  "attendancePolicy": "Minimum 75%; no makeup for quizzes",
  "auditWithdrawalPolicy": "Audit if attendance < 60%",
  "otherNotes": "Textbook, TA email, …",
  "createdBy": { "kerberos": "…", "name": "…", "at": "ISO8601" },
  "updatedBy": { "kerberos": "…", "name": "…", "at": "ISO8601" }
}
```

Validation/helpers: [src/utils/coursePolicy.js](src/utils/coursePolicy.js).
At least one field must be non-empty on `PUT` (`400 empty_policy`). Enrollment
check uses `semesterData.getEnrolledCourses()`; semester scope uses exported
`semesterData.resolveSemesterCode()`.

**My Calendar planner overlay** — [src/utils/plannerClasses.js](src/utils/plannerClasses.js)
reads `selectedCourses` + `timetableData` from `localStorage` (Show classes checkbox).

If you change planner `localStorage` shapes or JSONB columns, add a migration
or namespace keys — there are real users with stale data. For SQL, add a new
file under `server/db/migrations/`.

## Backend (`server/`)

A small Express app. Files:

- [server/src/index.js](server/src/index.js) — wires `cookie-parser`, JSON,
  `trust proxy 1`, and routers (`/auth`, `/api` → courses, catalog,
  calendarEvents, planner, occupiedRooms, personalEvents, reminders, attendance,
  semesterRoutes, history, coursePolicies, feedback, reports). `GET /` returns `{ name, ok }`.
- [server/src/config.js](server/src/config.js) — env loader. Looks for
  `server/.env` and the repo-root `.env`. Bails fast on missing OIDC/session
  vars. `DATABASE_URL` is optional (`config.databaseUrl`); Postgres-backed
  routes return 503 when unset.
- [server/src/semesterData.js](server/src/semesterData.js) — DB loaders + in-memory
  cache for active semester: catalog, calendar, extra-occupied, enrollments,
  rosters, app release config. Exports `resolveSemesterCode`, `getEnrolledCourses`,
  `normalizeCourseCode`, `normalizeKerberos`. `loadCatalog(semester?)` — active-semester courses.
  `loadCatalogExplorer()` — active courses (`offeredThisSemester: true`) plus one
  row per historical-only code (latest semester in `catalog_courses`,
  `offeredThisSemester: false`). Cache reloads on API restart after import scripts.
- [server/src/semesterRoutes.js](server/src/semesterRoutes.js) — public semester APIs:
  - `GET /api/semester/schedule` — holidays, swaps, breaks (+ optional `?semester=`)
  - `GET /api/semester/meta` — active semester summary
  - `GET /api/extra-occupied` — legacy overlay slots
- [server/src/oidc.js](server/src/oidc.js) — lazy `discovery()` against
  `OIDC_DISCOVERY_URL` (defaults to `auth.devclub.in`'s well-known doc); the
  config is cached.
- [server/src/session.js](server/src/session.js) — JWT cookie helpers:
  - `cg_flow` (~10 min, holds `{ v: pkceVerifier, s: state, app?: 1 }` between
    `/auth/login` and `/auth/callback`; `app: 1` when `?app=1` for mobile).
  - `cg_session` (~30 d, holds `{ kerberos, name, email, picture }`).
  - Both are httpOnly, SameSite=Lax, `Secure` in production.
  - `requireSession` middleware → 401 `{"error":"not_authenticated"}`.
- [server/src/auth.js](server/src/auth.js) — `GET /auth/login`,
 `GET /auth/callback`, `POST/GET /auth/logout`. Optional `?app=1` on
 `/auth/login` marks the flow for the Flutter app; the callback then 302s to
 `{MOBILE_APP_SCHEME}://auth/callback?token=…` instead of the SPA. Add
 `&desktop=1` with `app=1` for Linux/Windows: callback returns an HTML page
 with a copyable token ([desktopAuthPage.js](server/src/desktopAuthPage.js))
 instead of the custom scheme. Web logins
  (no `app=1`) still redirect to `${FRONTEND_ORIGIN}/?login=success` with
  `cg_session` set as a cookie.
- [server/src/courses.js](server/src/courses.js) — enrollments + rosters from Postgres
  via `semesterData.js`. Exposes `GET /api/me`, `GET /api/me/courses`,
  `GET /api/courses/:code/students`, `GET /api/health` (active semester stats).
  Exports `getEnrolledCourses(kerberos)` for the calendar router.
- [server/src/catalog.js](server/src/catalog.js) — DB-backed catalog (no auth):
  - `GET /api/catalog` — `{ courses, semesterCode, count }` with `ETag` +
    `Cache-Control: public, max-age=0, must-revalidate`; honours
    `If-None-Match` and returns `304` on a match. Active semester only (planner,
    rooms, mobile `CatalogProvider`).
  - `GET /api/catalog/explorer` — `{ courses, semesterCode, count, offeredCount }`;
    each course includes `offeredThisSemester`. Same caching headers as `/catalog`.
    Used by web/mobile course explorer and detail fallback — do not use for planner
    add-course search (stick to `/api/catalog`).
  - `GET /api/catalog/meta` — `{ semesterCode, count, etag }` for cheap
    revalidation. Web SPA loads active catalog + explorer via
    [SemesterDataContext.jsx](src/data/SemesterDataContext.jsx) at boot.
- [server/src/appVersion.js](server/src/appVersion.js) — minimum Flutter APK
  from `app_release_config` table. `GET /api/app/version` →
  `{ android: { version, build, downloadUrl } }`. Release APK at
  `https://classgrid.devclub.in/app/classgrid.apk` (`./deploy.sh --apk`).
  Run `./scripts/release-android-apk.sh` to bump DB row + deploy.
- [server/src/db.js](server/src/db.js) — lazy `pg` pool from `DATABASE_URL`.
- [server/src/planner.js](server/src/planner.js) — per-user timetable plan:
  - `GET /api/me/plan` — load saved plan (requires session).
  - `PUT /api/me/plan` — full replace `{ selectedCourses, timetableData }`
    (requires session). Upsert on `kerberos`.
- [server/src/calendarEvents.js](server/src/calendarEvents.js) — **shared**
  course calendar (mounted at `/api`):
  - `GET /api/events?from=&to=&courses=` — list events in a date range for the
    given comma-separated course codes. No auth required. If the caller has a
    valid session, enrolled courses from `studentCourses.json` are merged into
    the filter automatically.
  - `POST /api/events` — create (requires session).
  - `PATCH /api/events/:id` — update (requires session).
  - `DELETE /api/events/:id` — delete (requires session).
- [server/src/personalEvents.js](server/src/personalEvents.js) — **private**
  calendar events (requires session for all routes):
  - `GET /api/me/events?from=&to=` — list own events in range.
  - `POST /api/me/events` — create.
  - `PATCH /api/me/events/:id` — update own row only.
  - `DELETE /api/me/events/:id` — delete own row only.
- [server/src/reminders.js](server/src/reminders.js) — **mobile** class/event
  reminder subscriptions (requires session; table `user_reminders`). The app
  still fires OS notifications locally; this API syncs which bells are enabled:
  - `GET /api/me/reminders` — future reminders for the signed-in user (purges expired rows).
  - `POST /api/me/reminders` — upsert `{ key, title, body, eventStart }` (ISO8601).
  - `PUT /api/me/reminders` — replace all with `{ reminders: [...] }` (login migration).
  - `DELETE /api/me/reminders/:key` — remove one (`key` URL-encoded).
- [server/src/attendance.js](server/src/attendance.js) — **mobile** attendance
  buckets (requires session; table `user_course_attendance`). One row per
  `(kerberos, course_code, session_kind)` with counter columns + `by_date` JSONB:
  - `GET /api/me/attendance` — list buckets for the signed-in user.
  - `PUT /api/me/attendance` — full replace `{ buckets: [...] }` (login migration).
  - `PATCH /api/me/attendance` — atomic mark `{ courseCode, sessionKind, date, status? }`.
- [server/src/occupiedRooms.js](server/src/occupiedRooms.js) — manual room
  occupancy:
  - `GET /api/rooms/occupied?date=&time=` — active markings for that calendar
    date and HHMM time (public read).
  - `POST /api/rooms/occupied` — mark a room (requires session).
  - `DELETE /api/rooms/occupied/:id` — remove own marking (requires session).
- [server/src/history.js](server/src/history.js) — **catalog history** (public read; no auth):
  - `GET /api/semesters` — list semesters with catalog counts.
  - `GET /api/courses/:courseCode/offerings` — past/current offerings for one course.
  - `GET /api/instructors/search?q=` — search instructors by name or email.
  - `GET /api/instructors/:email/offerings` — all courses taught by one instructor email.
  - `GET /api/students/search?q=` — search students by kerberos or roster name.
  - `GET /api/students/:kerberos/offerings` — enrolled courses across semesters + profile (`hostel`, branch, entry year).
- [server/src/coursePolicies.js](server/src/coursePolicies.js) — **course policy** (session + enrollment required):
  - `GET /api/courses/:courseCode/policy` — load policy for active semester (`403 not_enrolled` if caller not registered).
  - `PUT /api/courses/:courseCode/policy` — upsert `{ markingScheme, attendancePolicy, auditWithdrawalPolicy, otherNotes }` with `createdBy`/`updatedBy`.
- [server/src/feedback.js](server/src/feedback.js) — **feature feedback** (optional session):
  - `POST /api/feedback` — `{ message, category?, pageContext?, client? }`; attaches kerberos when logged in; `429 rate_limited` after 10/hour per kerberos.
- [server/src/reports.js](server/src/reports.js) — **content reports** (session required):
  - `POST /api/reports` — `{ targetKind, targetId, reason, details? }`; builds `target_snapshot` server-side; `409 duplicate_report` for open duplicate; `404 target_not_found`.
- [server/src/adminAuth.js](server/src/adminAuth.js) — **admin gate** (session + allowlist):
  - Parses `ADMIN_KERBERSES` from env (comma-separated lowercase kerberos ids; empty list → all admin routes 403).
  - `requireAdmin` middleware: 401 `not_authenticated`, 403 `not_admin`.
- [server/src/admin.js](server/src/admin.js) — **web admin panel API** (all routes require admin):
  - `GET /api/admin/me` — `{ ok, kerberos }` client gate check.
  - `GET /api/admin/summary` — health stats, explorer counts, feedback totals, open report count.
  - `GET /api/admin/feedback?limit=&offset=&category=` — paginated `app_feedback`.
  - `GET /api/admin/reports?status=&limit=&offset=` — paginated `content_reports`.
  - `PATCH /api/admin/reports/:id` — `{ status }` (`open` \| `reviewed` \| `dismissed` \| `actioned`); sets `reviewed_by_kerberos` + `reviewed_at`.
  - `DELETE /api/admin/content/course-events/:id` — admin delete (no creator check).
  - `DELETE /api/admin/content/occupied-rooms/:id` — admin delete (bypass marker restriction).
  - `DELETE /api/admin/content/course-policies/:semester/:courseCode` — remove policy row.

Postgres routers return 503 `{ error: "database_unavailable" }` when
`DATABASE_URL` is unset.

### Auth flow

```
Browser → /auth/login → set cg_flow → 302 to IdP authorize (PKCE S256)
       ↓
       ← 302 /auth/callback?code
Backend exchanges code (PKCE verifier from cg_flow), fetches userinfo
(scope includes `kerberos`), sets cg_session, 302s to /?login=success.
SPA's Generator.jsx on login: GET /api/me/plan — if a saved plan exists,
restore it; else on first login fetch /api/me/courses and replace the plan.
Auto-fetch (toolbar) always confirms, then GET /api/me/courses and
PUT /api/me/plan (full replace).
```

The SPA's `AuthProvider` ([src/auth/AuthContext.jsx](src/auth/AuthContext.jsx))
calls `GET /api/me` on mount to populate `user`. All fetches use
`credentials: 'include'` and respect `REACT_APP_API_BASE` for cross-origin
dev. Auto-fetch in the planner calls the same `/api/me/courses` endpoint
when the user is signed in; if not signed in, the button starts IITD login.

### OIDC scopes / claims used

`openid profile email kerberos hostel`. The `kerberos` claim (from `userinfo`) is
the lookup key into `student_enrollments`; `hostel` is upserted into `students`
on each login when present. Everything is lowercased and trimmed before lookup. If you add a new scope/claim, also extend the session
payload in [server/src/auth.js](server/src/auth.js).

## Mobile app (`app/`)

A **Flutter** (Android-first) client with feature parity to the web SPA, talking
to the **same** `classgrid.devclub.in` backend — no duplicate business rules on
device. [ANDROID.md](ANDROID.md) is the older Expo/monorepo roadmap and is
**superseded** by this app (notably auth: external browser + deep link, not
Bearer tokens).

### Tech stack

| Layer | Package / pattern |
|-------|-------------------|
| Framework | Flutter 3 / Dart 3.10+ (`app/pubspec.yaml`) |
| HTTP | `dio` — session replayed as `Cookie: cg_session=…` header |
| Auth storage | `flutter_secure_storage` (JWT from OAuth deep link) |
| Guest / cache | `shared_preferences` — same key names as web `localStorage` |
| OAuth UI | `url_launcher` (system browser) + `app_links` (deep link return) |
| State | `provider` (`ChangeNotifier` + `MultiProvider`) |
| Fonts | `google_fonts` — Inter, Fraunces, IBM Plex Mono |
| Share / ICS | `share_plus` + `path_provider` |
| Dates | `intl` |
| Local notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` — [class_notification_service.dart](app/lib/notifications/class_notification_service.dart) |

No code generation, no Riverpod, no bundled catalog JSON.

### Project layout

```
app/
├── lib/
│   ├── main.dart                 # bootstrap, MultiProvider wiring
│   ├── config.dart               # API_BASE dart-define, session cookie name
│   ├── api/                      # thin REST wrappers over ApiClient
│   │   ├── api_client.dart       # dio + secure session + ApiException
│   │   ├── catalog_api.dart
│   │   ├── planner_api.dart
│   │   ├── calendar_events_api.dart
│   │   ├── personal_events_api.dart
│   │   ├── occupied_rooms_api.dart
│   │   ├── course_policy_api.dart
│   │   └── attendance_api.dart
│   ├── core/                     # pure Dart ports of src/utils + Generator logic
│   │   ├── timing.dart           # parseTimingStr, toMinutes
│   │   ├── clashes.dart          # flattenSessions, conflictIndices, countConflicts
│   │   ├── semester_schedule.dart# getAcademicDay, holidays/swaps/breaks
│   │   ├── calendar_events.dart  # event types, schedule validation, EventDraft
│   │   ├── course_policy.dart    # policy draft validation, policyPayload
│   │   ├── planner_classes.dart  # show-classes overlay for calendar
│   │   ├── attendance.dart       # bucket stats, mark transitions, prompt keys
│   │   └── ics.dart              # RFC 5545 generateICS
│   ├── models/                   # JSON (de)serialization
│   │   ├── course.dart, session.dart, plan.dart, user.dart
│   │   ├── calendar_event.dart, occupied_room.dart, actor.dart
│   │   ├── course_policy.dart
│   │   └── academic_day.dart
│   ├── state/
│   │   ├── auth_provider.dart    # GET /api/me, login/logout
│   │   ├── catalog_provider.dart # GET /api/catalog + offline cache (planner)
│   │   ├── explorer_catalog_provider.dart  # GET /api/catalog/explorer (Courses tab)
│   │   └── planner_store.dart    # guest local + signed-in DB sync
│   ├── storage/
│   │   ├── local_store.dart      # SharedPreferences (planner, catalog, guest events)
│   │   ├── reminder_store.dart
│   │   ├── attendance_store.dart # attendance buckets + post-class notify prefs
│   │   └── cgpa_store.dart       # CGPA calculator prefs (prior CGPA, semester rows)
│   ├── notifications/
│   │   └── class_notification_service.dart  # class reminders + attendance prompts
│   ├── theme/
│   │   ├── tokens.dart           # OKLCH → sRGB from src/index.css
│   │   └── app_theme.dart        # ThemeData, AppText helpers
│   ├── screens/
│   │   ├── home_shell.dart       # bottom nav + IndexedStack
│   │   ├── plan_screen.dart
│   │   ├── courses_screen.dart
│   │   ├── course_detail_screen.dart
│   │   ├── empty_halls_screen.dart
│   │   ├── attendance_screen.dart
│   │   └── calendar_screen.dart
│   └── widgets/
│       ├── auth_deep_link_listener.dart  # app_links → AuthProvider
│       ├── common.dart           # Pill, StatusBanner, EmptyState, PageHeader
│       ├── profile_button.dart   # IITD login / account menu
│       ├── timetable_grid.dart
│       ├── edit_timing_sheet.dart
│       ├── event_form_sheet.dart
│       ├── course_policy_sheet.dart
│       └── academic_calendar_sheet.dart
├── test/core_test.dart           # unit tests for core/
└── android/                      # Flutter Android; notification permissions + scheduled-alarm receivers
```

iOS scaffold exists under `app/ios/` but the app is **Android-first**; no iOS-specific auth or cookie work has been validated.

### Navigation (web route → mobile screen)

| Web route | Mobile tab / screen | Notes |
|-----------|---------------------|-------|
| `/` Generator | **Plan** tab — [plan_screen.dart](app/lib/screens/plan_screen.dart) | Push routes for add-course sheet, edit-timing sheet |
| `/course-explorer` | **Courses** tab — [courses_screen.dart](app/lib/screens/courses_screen.dart) | `ExplorerCatalogProvider`; **Not offered** pill on historical rows |
| `/course/:code` | **Course detail** — [course_detail_screen.dart](app/lib/screens/course_detail_screen.dart) | Active catalog → explorer → offerings API; **Not offered** banner; roster/policy only when offered |
| `/rooms` | **Rooms** tab — [rooms_screen.dart](app/lib/screens/rooms_screen.dart) | Search + building filter; button → Empty halls |
| `/rooms/:roomSlug` | **Room detail** — [room_detail_screen.dart](app/lib/screens/room_detail_screen.dart) | Pushed from Rooms list; list + week grid |
| `/empty-halls` | **Empty halls** — [empty_halls_screen.dart](app/lib/screens/empty_halls_screen.dart) | Pushed from Rooms (not a bottom-nav tab) |
| (drawer Tools) | **Attendance** — [attendance_screen.dart](app/lib/screens/attendance_screen.dart) | Pushed from drawer; not a bottom-nav tab |
| (drawer Tools) | **Prof explorer** — [prof_explorer_screen.dart](app/lib/screens/prof_explorer_screen.dart) | Search instructors; [prof_detail_screen.dart](app/lib/screens/prof_detail_screen.dart) for offerings |
| (drawer Tools) | **Student explorer** — [student_explorer_screen.dart](app/lib/screens/student_explorer_screen.dart) | Search students; [student_detail_screen.dart](app/lib/screens/student_detail_screen.dart) for courses + hostel |
| (drawer Tools) | **CGPA calculator** — [cgpa_calculator_screen.dart](app/lib/screens/cgpa_calculator_screen.dart) | SGPA + projected CGPA; local prefs only |
| `/calendar` | **Calendar** tab — [calendar_screen.dart](app/lib/screens/calendar_screen.dart) | |
| Navbar login | **ProfileButton** in app bar — [profile_button.dart](app/lib/widgets/profile_button.dart) | Opens ClassGrid in system browser |

[home_shell.dart](app/lib/screens/home_shell.dart) uses a `NavigationBar` +
`IndexedStack` so tabs retain scroll/state. OAuth return uses the
`classgrid://auth/callback` deep link (see Authentication).

### Bootstrap ([main.dart](app/lib/main.dart))

1. `ClassNotificationService.instance.init()` — timezone DB, notification channel,
   Android permission prompts (`POST_NOTIFICATIONS`, exact alarms). **Scaffold only:**
   no class reminders are scheduled from the planner yet.
2. `ApiClient.create()` — loads persisted `cg_session` from secure storage,
   attaches dio interceptor.
3. `LocalStore.create()` — SharedPreferences singleton.
4. `VersionGate` — `GET /api/app/version` vs `package_info_plus`; outdated builds
   stay on [update_required_screen.dart](app/lib/screens/update_required_screen.dart).
   Skip locally: `--dart-define=SKIP_VERSION_CHECK=true`.
5. `CatalogProvider.load()` — seed from cache, then `GET /api/catalog` with
   `If-None-Match` revalidation (active semester; planner + add-course).
5a. `ExplorerCatalogProvider.load()` — `GET /api/catalog/explorer` (Courses tab).
5b. `SemesterDataProvider.load()` — schedule + extra-occupied from API; sets
   active `SemesterScheduleConfig` for `getAcademicDay()`.
6. `PlannerStore.initGuest()` — read `selectedCourses` / `timetableData` locally.
7. `AuthProvider.init()` → `GET /api/me`; on auth change,
   `PlannerStore.onUserChanged()` loads DB plan or silent auto-fetch on first login.

API service objects (`CalendarEventsApi`, `PersonalEventsApi`, `OccupiedRoomsApi`)
are registered as plain `Provider`s; stores are `ChangeNotifierProvider`s.

### Authentication

Login happens on the **ClassGrid website in the system browser**, then the app
is reopened via a deep link. Requires backend support for `GET /auth/login?app=1`
(deploy `./deploy.sh --api` after auth changes).

```
ProfileButton → url_launcher opens GET {API_BASE}/auth/login?app=1
     ↓
Backend sets cg_flow { app: 1 }, 302 → auth.devclub.in OAuth (PKCE)
     ↓
User completes IITD login in Chrome / system browser (same as web)
     ↓
Backend /auth/callback sets cg_session cookie, 302 → classgrid://auth/callback?token=<JWT>
     ↓
Android shows "Open in ClassGrid?" → app_links → AuthDeepLinkListener
     ↓
AuthProvider.completeLogin(token) → secure storage + GET /api/me
     ↓
Subsequent API calls: Cookie: cg_session=<JWT> (dio interceptor)
```

Implementation: [profile_button.dart](app/lib/widgets/profile_button.dart),
[auth_provider.dart](app/lib/state/auth_provider.dart),
[auth_deep_link_listener.dart](app/lib/widgets/auth_deep_link_listener.dart),
[api_client.dart](app/lib/api/api_client.dart). Deep link registered in
[AndroidManifest.xml](app/android/app/src/main/AndroidManifest.xml)
(`classgrid` scheme) and [Info.plist](app/ios/Runner/Info.plist).

Backend: [auth.js](server/src/auth.js) reads `?app=1`, stores `app: 1` in
`cg_flow`, redirects to `config.mobileAppScheme` (env `MOBILE_APP_SCHEME`,
default `classgrid`) with the session JWT in the `token` query param.
`setSessionCookie` still sets the httpOnly cookie for the browser tab; the app
reads the same JWT from the deep link.

401 responses clear the stored session; the UI shows the login button again.

### Networking

[api_client.dart](app/lib/api/api_client.dart) centralizes:

- Base URL from `AppConfig.apiBase` (`--dart-define=API_BASE=…`, default prod).
- `requestJson()` — throws `ApiException` with backend `error` codes on 4xx.
- Session cleared automatically on 401.

| Wrapper | Endpoints | Auth |
|---------|-----------|------|
| [catalog_api.dart](app/lib/api/catalog_api.dart) | `GET /api/catalog` | none |
| [app_version_api.dart](app/lib/api/app_version_api.dart) | `GET /api/app/version` | none |
| [planner_api.dart](app/lib/api/planner_api.dart) | `GET/PUT /api/me/plan`, `GET /api/me/courses` | session |
| [calendar_events_api.dart](app/lib/api/calendar_events_api.dart) | `GET/POST/PATCH/DELETE /api/events` | read public; write session |
| [personal_events_api.dart](app/lib/api/personal_events_api.dart) | `GET/POST/PATCH/DELETE /api/me/events` | session |
| [reminders_api.dart](app/lib/api/reminders_api.dart) | `GET/POST/PUT/DELETE /api/me/reminders` | session |
| [attendance_api.dart](app/lib/api/attendance_api.dart) | `GET/PUT/PATCH /api/me/attendance` | session |
| [history_api.dart](app/lib/api/history_api.dart) | `GET /api/semesters`, `/api/courses/:code/offerings`, `/api/instructors/search`, `/api/instructors/:email/offerings`, `/api/students/search`, `/api/students/:kerberos/offerings` | none |
| [course_policy_api.dart](app/lib/api/course_policy_api.dart) | `GET/PUT /api/courses/:code/policy` | session + enrollment |
| [feedback_api.dart](app/lib/api/feedback_api.dart) | `POST /api/feedback` | optional session |
| [reports_api.dart](app/lib/api/reports_api.dart) | `POST /api/reports` | session |
| [occupied_rooms_api.dart](app/lib/api/occupied_rooms_api.dart) | `GET/POST/DELETE /api/rooms/occupied` | read public; write session |

Payload shapes match the web `src/utils/*Api.js` modules and Postgres tables
documented above.

### Local notifications

Device-side **local** reminders for planned classes (not server push). Implemented
in [class_notification_service.dart](app/lib/notifications/class_notification_service.dart)
and initialized from [main.dart](app/lib/main.dart) before `runApp`.

**Current state:** plugin init, Android channel (`class_reminders`), timezone
setup, and **per-item 30‑minute reminders** from the calendar day dialog (bell
on each class / timed event). Signed-in users sync toggles via
[reminders_api.dart](app/lib/api/reminders_api.dart) → `user_reminders` Postgres;
guests keep [reminder_store.dart](app/lib/storage/reminder_store.dart) in
SharedPreferences. OS scheduling stays in
[class_notification_service.dart](app/lib/notifications/class_notification_service.dart)
via `zonedSchedule`. All-day / EOD events and institute-calendar rows have no
bell (no concrete start time). Reminders reschedule on app launch.

**Dependencies:** `flutter_local_notifications`, `timezone`, `flutter_timezone`
([app/pubspec.yaml](app/pubspec.yaml)).

**Android setup** (required for scheduled alarms):

- Permissions in [AndroidManifest.xml](app/android/app/src/main/AndroidManifest.xml):
  `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `SCHEDULE_EXACT_ALARM`.
- Receivers: `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`
  (see plugin readme — declared in the app manifest).
- Gradle desugaring in [app/android/app/build.gradle.kts](app/android/app/build.gradle.kts):
  `isCoreLibraryDesugaringEnabled = true`, `coreLibraryDesugaring` dependency
  (required by `flutter_local_notifications` v10+ for `zonedSchedule`).

**Public API (today):**

- `ClassNotificationService.instance.init()` — idempotent; call once at startup.
- `details` — shared `NotificationDetails` for the `class_reminders` channel.
- `localTzDateTime(DateTime)` — wall-clock → `TZDateTime` in the device zone.

When adding schedulers, use `FlutterLocalNotificationsPlugin.zonedSchedule` with
`AndroidScheduleMode.exactAllowWhileIdle` when `canScheduleExactNotifications()`
is true, else fall back to `inexactAllowWhileIdle`. Cancel/reschedule on planner
edits so stale alarms do not fire. No backend or FCM — reminders are computed on
device from the cached plan.

### State & persistence

**PlannerStore** ([planner_store.dart](app/lib/state/planner_store.dart)) mirrors
[Generator.jsx](src/pages/Generator.jsx):

- Guests: `LocalStore.savePlanLocal` on every edit (`selectedCourses`,
  `timetableData` keys — same JSON shape as web).
- Signed-in: `GET /api/me/plan` on login; debounced `PUT` (~800 ms) on edit;
  `_skipNextSave` after DB load / auto-fetch replace.
- Auto-fetch: confirmation dialog → `GET /api/me/courses` → full plan replace +
  immediate `PUT`.
- First login with empty DB: silent auto-fetch (no dialog).

**CatalogProvider** ([catalog_provider.dart](app/lib/state/catalog_provider.dart)):
loads `GET /api/catalog` with `If-None-Match`, caches JSON + etag in
SharedPreferences for offline render. `byCode()` is the course lookup helper for
planner add-course and active-semester features.

**ExplorerCatalogProvider** ([explorer_catalog_provider.dart](app/lib/state/explorer_catalog_provider.dart)):
loads `GET /api/catalog/explorer` at boot. Powers the Courses tab list; each
`Course` has `offeredThisSemester` (default `true`). Detail screen falls back to
explorer then `HistoryApi` offerings (`Course.fromOffering(..., offeredThisSemester: false)`).

**SemesterDataProvider** ([semester_data_provider.dart](app/lib/state/semester_data_provider.dart)):
loads `GET /api/semester/schedule` and `GET /api/extra-occupied`; sets active
schedule via `setActiveSemesterSchedule()`; caches in SharedPreferences.

**LocalStore** ([local_store.dart](app/lib/storage/local_store.dart)):

| Key | Purpose |
|-----|---------|
| `selectedCourses`, `timetableData` | Guest/signed-in planner cache |
| `cg_catalog_cache`, `cg_catalog_etag` | Catalog offline fallback |
| `cg_calendar_events` | Guest-only personal events (legacy key name) |

Signed-in personal events use Postgres via `/api/me/events`, not local storage.

### Core logic (keep in sync with web)

When changing algorithms, update **both** the JS source and the Dart port, then
run `flutter test`:

| Dart module | Web source |
|-------------|------------|
| [core/timing.dart](app/lib/core/timing.dart) | `parseTimingStr` in [Generator.jsx](src/pages/Generator.jsx) |
| [core/clashes.dart](app/lib/core/clashes.dart) | clash logic in Generator + [TimetableGrid.jsx](src/components/Timetable/TimetableGrid.jsx) |
| [core/semester_schedule.dart](app/lib/core/semester_schedule.dart) | [src/utils/semesterSchedule.js](src/utils/semesterSchedule.js) |
| [core/calendar_events.dart](app/lib/core/calendar_events.dart) | [src/utils/calendarEvents.js](src/utils/calendarEvents.js) |
| [core/course_policy.dart](app/lib/core/course_policy.dart) | [src/utils/coursePolicy.js](src/utils/coursePolicy.js) |
| [core/planner_classes.dart](app/lib/core/planner_classes.dart) | [src/utils/plannerClasses.js](src/utils/plannerClasses.js) |
| [core/attendance.dart](app/lib/core/attendance.dart) | mobile-only (no web parity yet) |
| [core/cgpa.dart](app/lib/core/cgpa.dart) | mobile-only (no web parity yet) |
| [core/ics.dart](app/lib/core/ics.dart) | `generateICS` in Generator.jsx |
| [core/room_schedule.dart](app/lib/core/room_schedule.dart) | [src/utils/roomSchedule.js](src/utils/roomSchedule.js) |
| [core/empty_halls.dart](app/lib/core/empty_halls.dart) | [src/utils/emptyHalls.js](src/utils/emptyHalls.js) |

Timing format, academic calendar rules, event validation, and ICS output must
stay identical. Semester date constants live in `semester_schedule.dart` and
`ics.dart` — bump each semester like the web `SEMESTER_START` / `SEMESTER_END`.

### Screens (feature notes)

**Plan** — course search/add bottom sheet, expandable course cards, tutorial/lab
picker via [edit_timing_sheet.dart](app/lib/widgets/edit_timing_sheet.dart),
[timetable_grid.dart](app/lib/widgets/timetable_grid.dart) with conflict hatch,
clash banner, auto-fetch toolbar action, academic calendar sheet, ICS export via
system share sheet. No PNG export.

**Courses** — `ExplorerCatalogProvider`: search, department filter sheet,
infinite scroll pagination (40/page). **Not offered** pill on historical-only
rows. Tap → course detail with **Add to plan** (uses last known slot data).

**Course detail** — resolves active catalog → explorer → offerings API.
Metadata, slot/timing summary, add-to-plan. **Not offered** pill + note when
`offeredThisSemester === false`. **Course policy** (enrolled only; read card +
[course_policy_sheet.dart](app/lib/widgets/course_policy_sheet.dart) for edit) and
roster link only for currently offered courses; past offerings history for all.

**Empty halls** — date + time pickers (defaults to now), `getAcademicDay` for
effective weekday; [empty_halls.dart](app/lib/core/empty_halls.dart) checks
lecture/tutorial/lab. Tap room → `RoomDetailScreen`; Mark/Details for Postgres
markings (login required). If catalog `lectureHall` is null, only manual
markings appear — run `scripts/db/sync_venues.js` and restart the API.

**Calendar** — Monday-first month grid, academic day markers, shared + personal
events, day-tap picker (course vs personal), [event_form_sheet.dart](app/lib/widgets/event_form_sheet.dart),
optional show-classes overlay from planner state, pull-to-refresh, academic
calendar sheet. Shared events fetched only for planner + enrolled course codes
(same 414-safe filter as web).

**CGPA calculator** (drawer → Tools) — semester SGPA and projected CGPA from
10-point grades; import plan courses for credits; prior CGPA/credits in
SharedPreferences. Logic in [core/cgpa.dart](app/lib/core/cgpa.dart); no API.

**Attendance** (drawer → Tools) — per-course % from planner sessions; mark
present/absent/excused per lecture/tutorial/lab on past dates. Signed-in sync via
`/api/me/attendance`. Optional post-class local notification toggle schedules
OS prompts at class end (`class_attendance_prompts` channel).

### Theme & widgets

Design tokens in [tokens.dart](app/lib/theme/tokens.dart) convert web OKLCH CSS
variables to Flutter `Color`s. [app_theme.dart](app/lib/theme/app_theme.dart)
builds `ThemeData` matching [DESIGN.md](docs/DESIGN.md): Inter body, Fraunces page
titles, IBM Plex Mono for data. Reusable chips/banners in [common.dart](app/lib/widgets/common.dart)
(`Pill` — not Material `Badge`).

### Commands

From `app/`:

```bash
flutter pub get
flutter analyze                    # should report no issues
flutter test                       # core logic unit tests
flutter run                        # production API (classgrid.devclub.in)
flutter run --dart-define=API_BASE=http://10.0.2.2:4000   # Android emulator → host :4000
flutter build apk --debug          # smoke-build
flutter build apk --release        # Play Store candidate
```

Local backend: run `server/` on port 4000 with `server/.env` (OIDC + DATABASE_URL).
Emulator uses `10.0.2.2`; physical device needs your LAN IP. Prod catalog requires
DB import + `./deploy.sh --api`. Explorer list is larger (~3k+ codes when historical
data is imported) — only the Courses tab fetches `/api/catalog/explorer`.

**Deploy:** sideload APK via `./scripts/release-android-apk.sh` (rsyncs to
`/var/www/classgrid/app/classgrid.apk`). Default `./deploy.sh` does not upload the
APK. Backend/catalog deploy is shared with web.

### Deferred / parity gaps

| Feature | Web | Mobile |
|---------|-----|--------|
| PNG timetable export | `html2canvas-pro` | not implemented |
| Course roster donut | `courseStudents.json` | not implemented (no API) |
| Deep links / app links | n/a | not implemented |
| Local class reminders | n/a | Calendar day dialog: 30‑min before class/timed event; signed-in sync via `/api/me/reminders` |
| Attendance tracker | n/a | Drawer → Attendance; `/api/me/attendance`; post-class mark notifications (opt-in) |
| CGPA calculator | n/a | Drawer → CGPA calculator; client-only SGPA/CGPA |
| Push notifications (FCM / server) | n/a | not implemented (reminders are local OS alarms + API sync only) |
| Catalog `If-None-Match` revalidation | n/a | implemented in `catalog_provider.dart` |
| Bearer / mobile OAuth routes | n/a | intentionally not used |

### Mobile edit recipes

- **Change timetable/clash/calendar math:** edit `app/lib/core/` **and** the
  matching `src/` module; run `flutter test`.
- **New authenticated API:** add route on server, wrapper in `app/lib/api/`,
  register in `main.dart` if needed, consume from screen/state.
- **New tab/screen:** add screen widget, slot into [home_shell.dart](app/lib/screens/home_shell.dart)
  `IndexedStack` + `NavigationBar` destinations.
- **Touch mobile login:** [auth_provider.dart](app/lib/state/auth_provider.dart),
  [auth_deep_link_listener.dart](app/lib/widgets/auth_deep_link_listener.dart),
  [profile_button.dart](app/lib/widgets/profile_button.dart), backend
  [auth.js](server/src/auth.js) (`?app=1` + deep-link redirect). Keep
  `classgrid://auth/callback` in AndroidManifest / Info.plist in sync with
  `MOBILE_APP_SCHEME`.
- **Touch planner sync:** [planner_store.dart](app/lib/state/planner_store.dart)
  + [local_store.dart](app/lib/storage/local_store.dart); keep key names aligned
  with web `localStorage`.
- **Touch course policy:** server [coursePolicies.js](server/src/coursePolicies.js)
  + migration `010_course_policies.sql`; web
  [CoursePolicySection.jsx](src/components/CoursePolicy/CoursePolicySection.jsx),
  [coursePolicyApi.js](src/utils/coursePolicyApi.js),
  [coursePolicy.js](src/utils/coursePolicy.js); mobile
  [course_policy_api.dart](app/lib/api/course_policy_api.dart),
  [course_detail_screen.dart](app/lib/screens/course_detail_screen.dart),
  [course_policy_sheet.dart](app/lib/widgets/course_policy_sheet.dart),
  [core/course_policy.dart](app/lib/core/course_policy.dart). Enrollment gate on
  client (`GET /api/me/courses`) and server (`403 not_enrolled`). Web edit is
  **inline** on Course Details (not a modal); textareas use `.field` on the
  `<textarea>` with `cdpolicy__form-note` height override — same pattern as My
  Calendar `mycal__form-note`.
- **Semester refresh:** run `./scripts/db/refresh_semester.sh SEMCODE` (or individual
  importers in `scripts/db/`), then `./deploy.sh --api` to restart the API cache.
- **Touch course explorer (historical / not offered):** server
  [semesterData.js](server/src/semesterData.js) `loadCatalogExplorer` +
  [catalog.js](server/src/catalog.js) `/api/catalog/explorer`; web
  [SemesterDataContext.jsx](src/data/SemesterDataContext.jsx) (`explorerCourses`),
  [CourseExplorer.jsx](src/pages/CourseExplorer.jsx),
  [CourseDetails.jsx](src/pages/CourseDetails.jsx),
  [historyApi.js](src/utils/historyApi.js) `offeringToCourse`; Flutter
  [explorer_catalog_provider.dart](app/lib/state/explorer_catalog_provider.dart),
  [courses_screen.dart](app/lib/screens/courses_screen.dart),
  [course_detail_screen.dart](app/lib/screens/course_detail_screen.dart),
  [course.dart](app/lib/models/course.dart) `offeredThisSemester`. Keep planner
  on `/api/catalog` only.
- **Bump ICS semester window:** [core/ics.dart](app/lib/core/ics.dart) and web
  Generator constants together.
- **Touch class notifications:** [class_notification_service.dart](app/lib/notifications/class_notification_service.dart)
  (schedule/cancel/reschedule), [reminder_store.dart](app/lib/storage/reminder_store.dart)
  + [reminders_api.dart](app/lib/api/reminders_api.dart) (signed-in sync),
  [server/src/reminders.js](server/src/reminders.js) + migration `006_user_reminders.sql`,
  [main.dart](app/lib/main.dart) (init + `onAuthChanged`). Android manifest + Gradle
  desugaring (see [Local notifications](#local-notifications)).

### Mobile gotchas

- **`API_BASE` is compile-time** — changing prod vs dev requires rebuild
  (`--dart-define`), not a runtime setting.
- **Browser login needs backend deploy** — `GET /auth/login?app=1` and the
  `classgrid://auth/callback` redirect only work after `./deploy.sh --api`.
- **Deep link scheme** — default `classgrid`; must match `MOBILE_APP_SCHEME` in
  `/etc/classgrid/api.env`, Android intent-filter, and iOS URL types.
- **Session token in URL** — one-time redirect over custom scheme; stored in
  secure storage immediately. Rotating `SESSION_SECRET` forces re-login.
- **Guest personal events** stay in SharedPreferences; signing in does not auto-
  migrate them to Postgres (same as web before migration — calendar uses API when
  logged in).
- **Catalog size** — active catalog JSON (~500+ KB) downloads once per cold start;
  cached locally in `CatalogProvider`. Explorer catalog is larger (historical codes);
  fetched separately by `ExplorerCatalogProvider` for the Courses tab only.
- **`use_null_aware_elements` lint** is disabled in [analysis_options.yaml](app/analysis_options.yaml)
  (stylistic preference for explicit `if` spreads in widgets).
- **Local notifications on Android** — users must grant notification permission
  (Android 13+) and often **Alarms & reminders** for exact `zonedSchedule` times.
  Some OEMs (Xiaomi, Motorola, …) delay background alarms unless battery
  optimization is disabled for ClassGrid. On **Linux desktop**, scheduled
  alarms may not fire until the platform plugin supports `zonedSchedule`; use
  Android for reliable reminders.

## Conventions

- **Indentation:** 4 spaces in JSX/JS, 4 spaces in CSS. Match the
  surrounding file rather than your default.
- **Components:** function components, default export, named exactly like
  the file. No `React.FC`, no `forwardRef` unless required.
- **Files:** components in `src/components/<Name>/<Name>.jsx` paired with
  `<Name>.css`. Pages in `src/pages/<Name>.jsx` paired with `<Name>.css`.
- **Styling:** consume design tokens from
  [src/index.css](src/index.css), reuse primitives from
  [src/styles/ui.css](src/styles/ui.css) (`.btn`, `.field`, `.panel`,
  `.badge`, `.mono`, `.serif`, etc.) **before** writing new local CSS.
  Per-component CSS files are for layout and bespoke surfaces, not for
  redefining buttons.
- **No `#000` / `#fff` and no SaaS-rainbow gradients.** See
  [DESIGN.md](DESIGN.md#what-we-avoid).
- **Mono for data, serif for page titles only, Inter for everything else.**
- **Imports:** stick to relative paths; CRA doesn't have aliases configured.
- **No `console.log` left in shipped code.** `console.error` is fine for
  truly unexpected failures (see `handleDownloadImage` in `Generator.jsx`).

### Form fields (web)

ClassGrid **does not** use BEM `field__label` / `field__input`. `.field` styles
the **control** (input, select, textarea), not a wrapper.

**Always use** [FormField.jsx](src/components/FormField/FormField.jsx):

```jsx
import FormField from '../components/FormField/FormField';

<FormField label="Category" htmlFor="my-category" className="form-field--fixed">
    <select id="my-category" className="field" … />
</FormField>
```

| Class | Where |
|-------|--------|
| `.field-label` | On the label/legend text only (FormField applies this) |
| `.field` | On `<input>`, `<select>`, or `<textarea>` only |
| `.form-field` | Wrapper stack (FormField root) |
| `.form-field--wide` | Full-width fields (forms, dialogs) |
| `.form-field--fixed` | ~220px filters (admin toolbars) |
| `.form-field--sm` | ~160px compact controls (empty halls date/time) |

**Never:** `<label className="field">`, `field__*`, or wrapping label+control in
a bordered `.field` box (`.field` has `width: 100%` and will stretch broken layouts).

Reference implementations: [FeedbackForm.jsx](src/components/FeedbackForm/FeedbackForm.jsx),
[EmptyLectureHalls.jsx](src/pages/EmptyLectureHalls.jsx) (`eh__controls`),
[AdminFeedback.jsx](src/pages/admin/AdminFeedback.jsx).

Run `npm run check:ui` before shipping new form UI (blocks invented `field__*` classes).

## Common edit recipes

- **Add a new route:** declare it in `src/App.js`, create
  `src/pages/<Name>.jsx` + `<Name>.css`, link from the navbar in
  [src/components/Navbar/Navbar.jsx](src/components/Navbar/Navbar.jsx).
- **Add a new shared component:** put it under `src/components/<Name>/`
  with its own CSS. Import design tokens; don't redeclare them.
- **Add form inputs:** use [FormField.jsx](src/components/FormField/FormField.jsx);
  see [Form fields (web)](#form-fields-web). Run `npm run check:ui`.
- **Refresh course/venue/student data for a new semester:** run
  `./scripts/db/refresh_semester.sh SEMCODE` (or individual importers in
  `scripts/db/`), then `./deploy.sh --api`. Edit `data/academic_calendar.json`
  for holidays/swaps — do **not** hand-edit legacy `src/*.json` stubs except
  for one-time `seed_from_files.js`.
- **Touch the ICS export:** all logic lives in `generateICS` inside
  [src/pages/Generator.jsx](src/pages/Generator.jsx); semester bounds come from
  `useSemesterSchedule()` (API). The output must stay RFC 5545-valid: CRLF line
  endings, a `VTIMEZONE` block for `Asia/Kolkata`, and per-event `UID` + `DTSTAMP`.
- **Touch the timetable grid:** layout/visuals live in
  [src/components/Timetable/TimetableGrid.jsx](src/components/Timetable/TimetableGrid.jsx)
  and `Timetable.css`. Conflict detection is duplicated in `Generator.jsx`
  (`stats` memo) and in the grid — keep both in sync if you change the
  algorithm.
- **Ship to production:** run `./deploy.sh` after merging data or UI changes
  that should go live. SPA changes are picked up immediately (nginx serves
  static files); API changes trigger an `npm ci --omit=dev` and
  `systemctl restart classgrid-api`. Use `./deploy.sh --static` or `--api`
  to scope the deploy. Only use `./deploy.sh --setup` when provisioning a
  new host.
- **Add a new backend endpoint:** add a route in
  [server/src/courses.js](server/src/courses.js) or a new router mounted in
  [server/src/index.js](server/src/index.js) (see [server/src/calendarEvents.js](server/src/calendarEvents.js)).
  If it's user-specific or a write, gate it with `requireSession` from
  [server/src/session.js](server/src/session.js). Then call it from the SPA via
  `apiFetch('/api/…')` from [src/auth/AuthContext.jsx](src/auth/AuthContext.jsx).
- **Touch My Calendar — shared events:** UI in
  [src/pages/MyCalendar.jsx](src/pages/MyCalendar.jsx); API in
  [src/utils/calendarEventsApi.js](src/utils/calendarEventsApi.js); helpers in
  [src/utils/calendarEvents.js](src/utils/calendarEvents.js); server
  [server/src/calendarEvents.js](server/src/calendarEvents.js); table
  `course_events`. Click a day → shared event (course required).
- **Touch My Calendar — personal events:** same page; API in
  [src/utils/personalEventsApi.js](src/utils/personalEventsApi.js); server
  [server/src/personalEvents.js](server/src/personalEvents.js); table
  `personal_events`. Day-click picker; purple chips on grid for personal events.
- **Touch planner sync:** [src/pages/Generator.jsx](src/pages/Generator.jsx),
  [src/utils/plannerApi.js](src/utils/plannerApi.js),
  [server/src/planner.js](server/src/planner.js), table `user_plans`.
- **Touch course explorer / not-offered courses:** server
  [semesterData.js](server/src/semesterData.js) + [catalog.js](server/src/catalog.js);
  web [SemesterDataContext.jsx](src/data/SemesterDataContext.jsx),
  [CourseExplorer.jsx](src/pages/CourseExplorer.jsx), [CourseDetails.jsx](src/pages/CourseDetails.jsx),
  [historyApi.js](src/utils/historyApi.js); Flutter
  [explorer_catalog_provider.dart](app/lib/state/explorer_catalog_provider.dart) +
  courses/detail screens. Planner stays on `/api/catalog` / `courses`, not explorer.
- **Touch student explorer:** server [semesterData.js](server/src/semesterData.js) `searchStudents` / `getStudentOfferings` + [history.js](server/src/history.js); table `students` (migration `013_students.sql`); web [StudentExplorer.jsx](src/pages/StudentExplorer.jsx), [StudentDetail.jsx](src/pages/StudentDetail.jsx), [historyApi.js](src/utils/historyApi.js); Navbar **Explore** dropdown; Flutter [student_explorer_screen.dart](app/lib/screens/student_explorer_screen.dart), [student_detail_screen.dart](app/lib/screens/student_detail_screen.dart), drawer Tools entry.
- **Touch course policy:** web [CoursePolicySection.jsx](src/components/CoursePolicy/CoursePolicySection.jsx)
  + [coursePolicyApi.js](src/utils/coursePolicyApi.js); server
  [coursePolicies.js](server/src/coursePolicies.js), table `course_policies`
  (migration `010_course_policies.sql`). Enrolled-only read/write; `CourseDetails`
  fetches `GET /api/me/courses` to show the section. Apply `.field` to the
  `<textarea>`, not the wrapper label (see `cdpolicy__form-note` in
  [CoursePolicy.css](src/components/CoursePolicy/CoursePolicy.css)).
- **Touch empty halls / manual occupancy:**
  [src/pages/EmptyLectureHalls.jsx](src/pages/EmptyLectureHalls.jsx),
  [src/utils/occupiedRoomsApi.js](src/utils/occupiedRoomsApi.js),
  [server/src/occupiedRooms.js](server/src/occupiedRooms.js), table
  `occupied_rooms`. Shared logic in `emptyHalls.js` / `empty_halls.dart`.
  Date + time pickers; room name → weekly schedule; **Mark** for manual occupancy.
- **Touch web admin panel:** routes in [src/App.js](src/App.js) (`/admin*` without
  navbar/footer); UI under [src/pages/admin/](src/pages/admin/); API wrappers in
  [adminApi.js](src/utils/adminApi.js); server [admin.js](server/src/admin.js) +
  [adminAuth.js](server/src/adminAuth.js). Add admins via `ADMIN_KERBERSES` in
  `server/.env` / `/etc/classgrid/api.env`. Run migration `012` before relying on
  `reviewed_by_kerberos` columns. No public nav link — admins visit `/admin` directly.
- **Touch academic calendar (holidays/swaps):** shared
  [src/utils/semesterSchedule.js](src/utils/semesterSchedule.js); modal
  [src/components/AcademicCalendar/AcademicCalendarButton.jsx](src/components/AcademicCalendar/AcademicCalendarButton.jsx)
  on Plan and Calendar; also powers ICS EXDATE/swap logic and empty-halls day
  resolution.
- **Run a DB migration on prod:** rsync `server/db/` to `/opt/classgrid-db/`,
  `sudo bash -c 'set -a && source /etc/classgrid/db.env && set +a && /opt/classgrid-db/migrate.sh'`
  on the VM (azureuser cannot read `/etc/classgrid/db.env` without sudo).
  `./deploy.sh --api` does **not** run migrations or restart Postgres.
- **Course policy 500 after deploy:** if `/api/courses/:code/policy` throws
  `resolveSemesterCode is not a function`, ensure
  [semesterData.js](server/src/semesterData.js) exports `resolveSemesterCode`
  (used by [coursePolicies.js](server/src/coursePolicies.js)).

## Gotchas

- **CRA + Node 18+:** if `npm start` fails with an OpenSSL error, you're on
  a too-new Node. Use Node 18 LTS or set
  `NODE_OPTIONS=--openssl-legacy-provider`.
- **Large roster imports:** `course_rosters` may be millions of rows when populated;
  use `scripts/db/import_student_data.js` (batched INSERT). Index on
  `(semester_code, course_code)` keeps roster API fast.
- **Shared production VM:** `./deploy.sh` only writes to `/var/www/classgrid`,
  `/opt/classgrid-api`, `/etc/classgrid`, and the `classgrid-api` systemd
  unit. Postgres lives separately under `/opt/classgrid-db/` and
  `/etc/classgrid/db.env` — do not touch other apps' vhosts, ports, or units.
  Other apps on the same host use different vhosts and ports (notably one of
  them owns `127.0.0.1:4000` — classgrid-api uses 4500 to stay out of the way).
  Do not restart nginx outside `deploy.sh`, run certbot globally, or edit
  unrelated site configs / units unless explicitly asked.
- **Postgres on a shared VM:** the `classgrid-postgres` container binds
  `0.0.0.0:5432`. ~26 MiB RAM at idle on top of the Docker daemon. No swap on
  the VM — watch memory if you add more containers. Never `docker compose down
  -v` on prod (destroys `classgrid_pgdata`).
- **Backend secrets:** OAuth client secret, `SESSION_SECRET`, and DB password
  live only in `/etc/classgrid/api.env` and `/etc/classgrid/db.env` on the VM
  (and `server/.env` locally, gitignored). Never commit them. Rotating
  `SESSION_SECRET` invalidates every active `cg_session` cookie (logs everyone
  out).
- **`cg_session` schema drift:** if you add fields to the session payload
  in [server/src/auth.js](server/src/auth.js), older signed cookies still
  verify but won't carry the new field. Default to `null`/`undefined` in
  handlers, or rotate `SESSION_SECRET` to force a re-login.
- **PNG export and OKLCH:** the whole color system is `oklch()`, which the
  original `html2canvas` cannot parse (it throws and the export silently
  fails). The PNG export therefore uses **`html2canvas-pro`** (a drop-in
  fork that supports `oklch()`/`lab()`/`color()`) — see the import in
  [src/pages/Generator.jsx](src/pages/Generator.jsx). Do not swap it back to
  plain `html2canvas`. After adding a new tinted block to the timetable,
  verify the `Export image` button on `/` still produces a correct PNG.
- **`localStorage` schema drift (planner):** parsing is wrapped in
  `try/catch` and falls back to `[]` / `{}`. If you change the shape, prefer a
  new key over silently mutating the old one. Stale `cg_calendar_events` keys
  may still exist in browsers from before the Postgres migration — safe to
  ignore; My Calendar no longer reads them.
- **`DATABASE_URL` missing:** Postgres routes (`/api/events`, `/api/me/plan`,
  `/api/me/events`, `/api/rooms/occupied`, `/api/catalog`, `/api/catalog/explorer`)
  return 503; auth and `/api/me` still work. Startup logs
  `[classgrid-api] database: DATABASE_URL not set`.
- **Course explorer vs active catalog:** `/api/catalog` is the active semester
  only (~1k courses). `/api/catalog/explorer` merges historical-only codes from
  `catalog_courses` (~3k+ when archives are imported). Do not point the planner
  or room schedules at the explorer endpoint — stale slot data for retired courses
  is intentional for browsing, not for live timetable logic.
- **My Calendar course filter:** shared events are fetched only for planner +
  enrolled course codes (never the full catalog — avoids HTTP 414). Personal
  events load independently when logged in.
- **Occupied rooms vs timetable:** timetable + extra-occupied API slots hide
  rooms from the free grid; Postgres markings show as **red** chips still in
  the grid. Markings are date-specific (`occupancy_date`), not recurring weekly.
- **No tests for most of the app.** `src/App.test.js` is the CRA default
  and is essentially a smoke test. Don't assume green CI means a feature
  works — run it in the browser.
- **Flutter app:** see [Mobile gotchas](#mobile-gotchas) — browser OAuth deep link,
  compile-time `API_BASE`, and core-logic parity with `src/` are the usual
  footguns.

## Out of scope

- **Custom course colors** and other UI preferences — not in Postgres yet.
- Postgres **session store** — IITD login sessions remain signed JWT cookies.
- **Google Calendar / ICS live sync** — planner exports a one-shot `.ics` file
  only; no subscribed feed or Google API integration yet.
- Mobile-app concerns **for the web SPA** — `src/` stays desktop-first. Keep
  responsive styles but don't reorganise it around a native shell; the native
  client is the separate Flutter app in `app/` (see Mobile app section).
