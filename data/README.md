# Semester source data

Operator inputs for [`scripts/db/`](../scripts/db/) importers. Data is written to **Postgres**, not bundled into the web or mobile clients.

| File | Purpose |
| --- | --- |
| [`Courses_Offered.csv`](Courses_Offered.csv) | Download from the IITD timetable site each semester → `node scripts/db/import_catalog.js --semester=CODE` |
| [`academic_calendar.json`](academic_calendar.json) | Term dates, holidays, timetable swaps, breaks → `node scripts/db/import_academic_calendar.js` |
| [`extra_occupied.json`](extra_occupied.json) | Weekly hall bookings not in the catalog → `node scripts/db/import_extra_occupied.js` |
| `Room_Allotment_Chart.pdf` | Optional local copy for venue sync; or set `ROOM_ALLOTMENT_PDF_URL` for [`extract_venue_map.py`](../scripts/extract_venue_map.py) |
| [`courses_offered_historical/`](courses_offered_historical/) | Past-semester CSV exports (`2201.csv`, …) → `node scripts/db/import_historical_catalog.js` |

See **[scripts/README.md](../scripts/README.md)** for the full refresh runbook.

Legacy stubs under [`src/`](../src/) (`courses.json`, `studentCourses.json`, …) are only used by one-time `seed_from_files.js` — do not regenerate them for routine updates.

Do not commit populated enrollment maps when multi-MB (PII).
