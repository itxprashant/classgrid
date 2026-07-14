# ClassGrid scripts

Operational tooling for **semester reference data** (course catalog, enrollments,
rosters, academic calendar, room overlay, Android version) and app releases.

Semester data lives in **Postgres** and is served by the API. Web and mobile
clients fetch it at runtime — nothing is bundled from `src/*.json` anymore.

---

## Quick reference

| Task | Command |
|------|---------|
| Full semester refresh (local or prod `DATABASE_URL`) | `./scripts/db/refresh_semester.sh 2601` |
| **LDAP student lists (VPN)** | `./scripts/fetch_student_enrollments.sh 2502 --fetch-only` then `--import` |
| Run any importer on **production VM** | `./scripts/db/run_on_prod.sh import_student_data.js --semester=2601` (add `--with-data` for full semester refresh / seed) |
| One-time seed from legacy JSON files | `node scripts/db/seed_from_files.js` |
| Verify API after refresh | `./scripts/db/check_semester.sh` |
| Rebuild per-prof `instructors[]` on existing catalog rows | `node scripts/db/backfill_instructors.js` (then `./deploy.sh --api`) |
| Prefill student hostels from CSV | `node scripts/db/import_student_hostels.js` (default: `data/student_hostels.csv`) |
| Local Postgres + migrate + seed | `./scripts/db/bootstrap_local.sh` |
| Ship Android APK + bump version in DB | `./scripts/android-keystore-init.sh` (once), then `./scripts/bump-app-version.sh` + `./scripts/release-android-apk.sh --build` — [docs/ANDROID_SIGNING.md](../docs/ANDROID_SIGNING.md) |
| Deploy code (restart API cache) | `./deploy.sh --api` |

---

## Prerequisites

### Environment

All `scripts/db/*.js` importers need **`DATABASE_URL`**:

```bash
export DATABASE_URL=postgresql://classgrid:PASSWORD@127.0.0.1:5432/classgrid
```

Or set it in `server/.env` (loaded automatically by `scripts/db/pg.js`).

**Production note:** `/etc/classgrid/api.env` on the VM uses
`DATABASE_URL=…@127.0.0.1:5432/…`, which only works **on the VM**. From your
laptop either:

- Use `./scripts/db/run_on_prod.sh …` (recommended — SSH via `mydevclub`), or
- SSH tunnel: `ssh -L 5432:127.0.0.1:5432 mydevclub` and connect with the prod
  password from `/etc/classgrid/db.env`.

### Deploy / SSH

Production deploy and `run_on_prod.sh` use your **`~/.ssh/config` Host alias**
`mydevclub` by default (same as `ssh mydevclub`). Shared helper:
[`scripts/lib/deploy_ssh.sh`](lib/deploy_ssh.sh).

Optional repo-root `deploy.env` (copy from [`deploy.env.example`](../deploy.env.example)):

```bash
DEPLOY_SSH_HOST=mydevclub
DEPLOY_DOMAIN=classgrid.devclub.in
```

Legacy explicit SSH (`DEPLOY_HOST`, `DEPLOY_USER`, `SSH_IDENTITY`) still works if
all three are set.

### Node dependencies

DB scripts use `pg` from the server package:

```bash
cd server && npm install
NODE_PATH=./node_modules node ../scripts/db/import_catalog.js --semester=2601
```

`run_on_prod.sh` and `bootstrap_local.sh` set `NODE_PATH` for you.

### Python (venue sync only)

`sync_venues.js` shells out to `scripts/extract_venue_map.py`, which needs
**PyPDF2**:

```bash
pip install PyPDF2
```

Set the allotment PDF when IITD publishes a new one:

```bash
export ROOM_ALLOTMENT_PDF_URL='https://web.iitd.ac.in/~tti/timetable/Room_Allotment_Chart_….pdf'
# optional local cache: data/Room_Allotment_Chart.pdf
```

**Campus room list (client fallback, no DB):** when the active catalog has no
`lectureHall` yet, web and Flutter merge [`data/campus_rooms.json`](../data/campus_rooms.json)
into `/rooms` so users can browse room names with “schedule pending” labels.
Regenerate from the latest allotment PDF and copy into client bundles:

```bash
./scripts/generate_campus_rooms.sh
# writes data/campus_rooms.json → public/campus_rooms.json + app/assets/campus_rooms.json
git add data/campus_rooms.json public/campus_rooms.json app/assets/campus_rooms.json
```

This does **not** update Postgres — use `sync_venues.js` for that after catalog import.
Deploy static assets (`./deploy.sh --static`) so `/campus_rooms.json` is live.

### Migrations

Before first import on any database:

```bash
source /etc/classgrid/db.env && /opt/classgrid-db/migrate.sh   # production
# or locally:
./scripts/db/bootstrap_local.sh
```

Migration **`008_semester_data.sql`** creates `semesters`, `catalog_courses`,
`student_enrollments`, `course_rosters`, `extra_occupied_slots`, and
`app_release_config`.

Migration **`009_catalog_instructor_email_idx.sql`** adds a partial index on
`lower(course_data->>'instructorEmail')` for prof search (apply before heavy
instructor queries on prod).

---

## Operator input files

These live under `data/` and are **not** shipped in the web bundle or APK:

| File | Purpose |
|------|---------|
| [`data/Courses_Offered.csv`](../data/Courses_Offered.csv) | IITD offered-courses export → catalog |
| [`data/academic_calendar.json`](../data/academic_calendar.json) | Term dates, holidays, timetable swaps, breaks |
| [`data/extra_occupied.json`](../data/extra_occupied.json) | Weekly hall bookings not in the official catalog |
| `data/Room_Allotment_Chart.pdf` | Optional local copy of the venue PDF |
| [`data/courses_offered_historical/`](courses_offered_historical/) | Past-semester `YYTT.csv` exports → `node scripts/db/import_historical_catalog.js` |

Legacy [`src/courses.json`](../src/courses.json), `studentCourses.json`, and
`courseStudents.json` are only used by **`seed_from_files.js`** for one-time
migration — do not edit them for routine refreshes.

---

## Historical catalog import (one-time / archive)

Past-semester CSV exports live in [`data/courses_offered_historical/`](../data/courses_offered_historical/) (`2201.csv`, …). Import into Postgres without activating those terms:

```bash
export DATABASE_URL=…
node scripts/db/import_historical_catalog.js          # all CSVs in the folder
node scripts/db/import_historical_catalog.js --semester=2502
node scripts/db/import_historical_catalog.js --dry-run  # parse only

# Production VM:
./scripts/db/run_on_prod.sh import_historical_catalog.js
```

Catalog imports now split comma-separated instructor names into
`course_data.instructors` (array of `{ name, email }`). Co-instructor emails
are filled by matching names across the full import batch.

If you upgraded parse logic **without** re-importing CSVs, backfill existing
rows instead:

```bash
node scripts/db/backfill_instructors.js
# Production VM:
./scripts/db/run_on_prod.sh backfill_instructors.js
./deploy.sh --api   # refresh in-memory active catalog cache
```

Re-importing the **active** semester CSV should use `import_catalog.js` instead
(historical script skips active rows). `./deploy.sh --api` is optional after
historical import alone (history endpoints read Postgres directly), but
**required** after backfill so `/api/catalog` serves the new `instructors`
field.

---

## Updating the current semester

Typical mid-semester fixes (catalog correction, new venues, refreshed rosters):

1. Update the relevant input file(s) under `data/`.
2. Run the matching importer(s) below, **or** the orchestrator:

```bash
export DATABASE_URL=…
./scripts/db/refresh_semester.sh 2601
```

3. Restart the API so the in-memory cache reloads:

```bash
./deploy.sh --api          # production
# or locally: restart npm start in server/
```

4. Verify:

```bash
./scripts/db/check_semester.sh
# or: curl https://classgrid.devclub.in/api/health
```

You can run individual steps instead of the full orchestrator — see the script
reference below.

---

## Starting a new semester

When IITD rolls to a new term (e.g. `2601` → `2602`):

### 1. Edit operator inputs

- **`data/academic_calendar.json`** — set `semester.code`, `label`,
  `classesStart`, `lastTeachingDay`, and the full holidays / swaps / breaks list
  for the new term. This file drives both the DB row and what clients show in
  “Holidays & timetable changes”.
- **Download** the new `Courses_Offered.csv` into `data/`.
- **Update** `ROOM_ALLOTMENT_PDF_URL` (or drop the new PDF at
  `data/Room_Allotment_Chart.pdf`) before venue sync.
- **`data/extra_occupied.json`** — clear or repopulate for the new term.
- Student LDAP pages use a semester prefix like `2602-`; `refresh_semester.sh`
  passes `--prefix=2602-` automatically from the semester code argument.

### 2. Import into Postgres

```bash
# Local or tunneled DATABASE_URL:
./scripts/db/refresh_semester.sh 2602

# Or on production VM directly:
./scripts/db/run_on_prod.sh --with-data -- ./scripts/db/refresh_semester.sh 2602
```

`refresh_semester.sh` runs importers in order and **activates** the new semester
(deactivates all others). Old semesters remain in the DB for archive access via
`?semester=2601` on API routes.

### 3. Deploy

```bash
./deploy.sh --api    # restart API (required)
./deploy.sh --static # only if you changed web/mobile code
```

No SPA rebuild is required for catalog-only updates — clients fetch from the API.

### 4. Verify

```bash
./scripts/db/check_semester.sh
```

Expect `activeSemester` to match the new code and `catalogCount` > 0.

### Known behaviour at rollover

- **`user_plans`** is not semester-scoped. Users may keep stale course codes until
  they edit their plan or use Auto-fetch after login.
- ICS export on web/mobile uses term bounds from the **active** semester schedule API.

---

## `scripts/db/` — script reference

### Orchestrators

| Script | Description |
|--------|-------------|
| [`refresh_semester.sh`](db/refresh_semester.sh) | Runs the full import chain for one semester code, activates it, prints restart reminder. Env: `CSV` overrides catalog CSV path. |
| [`bootstrap_local.sh`](db/bootstrap_local.sh) | Docker Postgres up → migrate → `seed_from_files.js`. For first-time dev setup. |
| [`run_on_prod.sh`](db/run_on_prod.sh) | Rsyncs `scripts/db/` plus only the inputs needed for the target importer (default). Pass `--with-data` for full seed sync; `--minimal` for DB-only jobs. Does **not** run from `./deploy.sh`. |
| [`check_semester.sh`](db/check_semester.sh) | Curls `/api/health`, `/api/semester/meta`, `/api/catalog/meta`, `/api/catalog/explorer`, extra-occupied count. Defaults to `https://${DEPLOY_DOMAIN}`. |

### Importers (Node)

| Script | Reads | Writes |
|--------|-------|--------|
| [`import_academic_calendar.js`](db/import_academic_calendar.js) | `data/academic_calendar.json` | `semesters` row (calendar JSONB, dates, label). Does **not** activate. |
| [`import_catalog.js`](db/import_catalog.js) | `data/Courses_Offered.csv` | Replaces `catalog_courses` for `--semester`; preserves existing `lectureHall` when CSV has none; bumps catalog ETag. **Requires semester row to exist** (run calendar import first). |
| [`import_historical_catalog.js`](db/import_historical_catalog.js) | `data/courses_offered_historical/*.csv` | Upserts stub `semesters` rows + replaces `catalog_courses` per file; never activates. Flags: `--dir`, `--semester`, `--dry-run`. |
| [`backfill_instructors.js`](db/backfill_instructors.js) | Existing `catalog_courses.course_data` | Rebuilds `instructors[]` + primary `instructor` / `instructorEmail` from stored name/email fields (no CSV). Run after parse upgrades; restart API after. |
| [`sync_venues.js`](db/sync_venues.js) | Room allotment PDF via [`extract_venue_map.py`](extract_venue_map.py) | Updates `course_data.lectureHall` in `catalog_courses`. |
| [`import_student_data.js`](db/import_student_data.js) | IITD LDAP (`ldapweb.iitd.ac.in`) | Replaces `student_enrollments` + `course_rosters` for `--semester`. Keeps student kerberos only (`aa1234567` or `abc123456`). Slow (many HTTP requests). |
| [`import_extra_occupied.js`](db/import_extra_occupied.js) | `data/extra_occupied.json` | Replaces `extra_occupied_slots` for `--semester`. |
| [`import_app_version.js`](db/import_app_version.js) | `app/pubspec.yaml` or `--version` / `--build` / `--url` | Upserts `app_release_config` (`android`). |
| [`activate_semester.js`](db/activate_semester.js) | — | Sets exactly one `semesters.is_active = true`. |
| [`seed_from_files.js`](db/seed_from_files.js) | Legacy `src/*.json`, `data/*`, `app/pubspec.yaml` | **One-time** bulk load of all tables; optional `--semester`, `--no-activate`. |

### Shared shell helpers

| File | Role |
|------|------|
| [`lib/deploy_ssh.sh`](lib/deploy_ssh.sh) | `load_deploy_env`, `init_deploy_ssh`, `require_deploy_ssh`, `can_deploy_ssh`, `remote` — used by `deploy.sh`, `run_on_prod.sh`, `release-android-apk.sh`. |

### Shared modules

| File | Role |
|------|------|
| [`pg.js`](db/pg.js) | `DATABASE_URL` pool, `parseArgs`, `withClient`, `computeCatalogEtag`. |
| [`parse_catalog_csv.js`](db/parse_catalog_csv.js) | CSV → course objects (`instructorEmail`, `instructors[]`). |
| [`parse_instructors.js`](db/parse_instructors.js) | Split multi-instructor CSV cells; resolve co-instructor emails across a batch. Re-exported from [`server/src/parse_instructors.js`](../server/src/parse_instructors.js) for DB scripts. |
| [`semester_code_meta.js`](db/semester_code_meta.js) | Derive label + dates from IITD YYTT codes (`2402` → Sem 2 Jan 2025, `2502` → Sem 2 Jan 2026, …). |
| [`refresh_semester_labels.js`](db/refresh_semester_labels.js) | Fix `semesters.label` / term dates in Postgres after meta changes (no catalog re-import). |
| [`import_catalog_core.js`](db/import_catalog_core.js) | Shared catalog upsert used by `import_catalog.js` and `import_historical_catalog.js` (dedupes duplicate course codes per semester; last row wins). |

### Supporting Python

| Script | Role |
|--------|------|
| [`extract_venue_map.py`](extract_venue_map.py) | Downloads/parses room allotment PDF; default stdout is `{ "COL106": ["LH 111", …], … }` (used by `sync_venues.js`). `--rooms-list` emits unique venue names for [`generate_campus_rooms.sh`](generate_campus_rooms.sh). |
| [`generate_campus_rooms.sh`](generate_campus_rooms.sh) | Runs `extract_venue_map.py --rooms-list` → `data/campus_rooms.json`; copies to `public/` and `app/assets/` for client fallback (no DB). |

---

## Other scripts (still maintained)

| Script | Description |
|--------|-------------|
| [`release-android-apk.sh`](release-android-apk.sh) | Build/stage APK, upsert version via `run_on_prod.sh` (when `ssh mydevclub` works) or local `import_app_version.js`, deploy `--api` + `--apk`. |

---

## Removed legacy scripts

The following pre-Postgres scripts were deleted; use the `scripts/db/` importers instead:

| Removed | Use instead |
|---------|-------------|
| `csv_to_json.py` | `import_catalog.js` |
| `sync_venues.py` | `sync_venues.js` + `extract_venue_map.py` |
| `fetch_student_courses.js` | `import_student_data.js` |
| `update_venues.sh` | `sync_venues.js` |
| `server/data/android-version.json` | `import_app_version.js` (reads `app/pubspec.yaml`) |

---

## LDAP student enrollments (VPN required)

IITD course rosters live at `https://ldapweb.iitd.ac.in/LDAP/courses/` — **intranet/VPN only**.

Use [`fetch_student_enrollments.sh`](fetch_student_enrollments.sh) (wrapper) or
[`import_student_data.js`](db/import_student_data.js) directly.

### Two-step (recommended when prod DB is remote)

```bash
# 1. On campus or IITD VPN — fetch JSON only (no DATABASE_URL needed)
./scripts/fetch_student_enrollments.sh 2502 --fetch-only
# → data/ldap_exports/2502/{studentCourses,courseStudents,meta}.json

# 2. Import into Postgres (local or prod)
export DATABASE_URL=postgresql://classgrid:…@127.0.0.1:5432/classgrid
./scripts/fetch_student_enrollments.sh 2502 --import

# Or copy JSON to the VM and:
./scripts/db/run_on_prod.sh import_student_data.js --semester=2502 --from-json
./deploy.sh --api
```

### One-shot (VPN + DATABASE_URL on same machine)

```bash
./scripts/fetch_student_enrollments.sh 2502
```

**Prerequisite:** a `semesters` row for `2502` must exist (FK). For archived terms,
import catalog/calendar first (`import_historical_catalog.js --semester=2502` or full
`refresh_semester.sh` for the active term).

Exported JSON is gitignored under `data/ldap_exports/` (PII).

---

## Production runbook (cheat sheet)

```bash
# First time after deploying migration 008
./scripts/db/run_on_prod.sh --with-data seed_from_files.js
./deploy.sh --api
./scripts/db/check_semester.sh

# Each semester refresh
# 1. Edit data/academic_calendar.json, data/Courses_Offered.csv, PDF URL, etc.
# 2. Import + activate
./scripts/db/run_on_prod.sh --with-data -- ./scripts/db/refresh_semester.sh 2602
# 3. Restart API
./deploy.sh --api
# 4. Verify
./scripts/db/check_semester.sh

# One-time historical archive + instructor backfill (if not re-importing active CSV)
./scripts/db/run_on_prod.sh import_historical_catalog.js
./scripts/db/run_on_prod.sh backfill_instructors.js
./deploy.sh --api
```

---

## API endpoints (what clients consume)

| Endpoint | Data |
|----------|------|
| `GET /api/catalog` | Active-semester course list + ETag (planner, rooms) |
| `GET /api/catalog/explorer` | All course codes on record + `offeredThisSemester` (course explorer UI) |
| `GET /api/catalog/meta` | Cheap revalidation |
| `GET /api/semester/schedule` | Holidays, swaps, breaks, term bounds |
| `GET /api/semester/meta` | Active semester summary |
| `GET /api/extra-occupied` | Legacy weekly overlay |
| `GET /api/me/courses` | Enrolled courses (auth) |
| `GET /api/courses/:code/students` | Course roster |
| `GET /api/semesters` | All semester stubs + catalog counts (history UI) |
| `GET /api/courses/:code/offerings` | Past/current catalog rows for one course code |
| `GET /api/instructors/search?q=` | Prof explorer search (by name or email) |
| `GET /api/instructors/:email/offerings` | Courses taught by one instructor |
| `GET /api/app/version` | Minimum Android build |
| `GET /api/health` | Active semester, catalog count, enrollment count |

All semester routes accept optional `?semester=CODE` for archived terms.
