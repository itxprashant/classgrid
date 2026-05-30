# Semester source data

Inputs for the refresh scripts in [`scripts/`](../scripts/). Generated outputs land in [`src/`](../src/) (`courses.json`, `studentCourses.json`, …).

| File | Purpose |
| --- | --- |
| `Courses_Offered.csv` | Download from the IITD timetable site each semester → `python3 scripts/csv_to_json.py` |
| `Room_Allotment_Chart_*.pdf` | Optional local copy for venue sync; [`scripts/sync_venues.py`](../scripts/sync_venues.py) can also fetch the PDF from IITD |

Do not commit populated enrollment maps (`studentCourses.json` / `courseStudents.json` when multi-MB). The repo ships tiny stubs under `src/`.
