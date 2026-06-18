#!/usr/bin/env bash
# Refresh semester reference data in Postgres.
# Requires DATABASE_URL (or server/.env with DATABASE_URL set).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SEMESTER="${1:-2601}"
CSV="${CSV:-${REPO_ROOT}/data/Courses_Offered.csv}"

if [[ -z "${DATABASE_URL:-}" ]]; then
  if [[ -f "${REPO_ROOT}/server/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/server/.env"
    set +a
  fi
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required (export it or set in server/.env)" >&2
  exit 1
fi

echo "==> Academic calendar"
node "${SCRIPT_DIR}/import_academic_calendar.js"

echo "==> Course catalog from ${CSV}"
node "${SCRIPT_DIR}/import_catalog.js" --semester="${SEMESTER}" --csv="${CSV}"

echo "==> Lecture hall venues"
node "${SCRIPT_DIR}/sync_venues.js" --semester="${SEMESTER}"

echo "==> Student enrollments + rosters"
node "${SCRIPT_DIR}/import_student_data.js" --semester="${SEMESTER}" --prefix="${SEMESTER}-"

echo "==> Extra-occupied overlay"
node "${SCRIPT_DIR}/import_extra_occupied.js" --semester="${SEMESTER}"

echo "==> App version"
node "${SCRIPT_DIR}/import_app_version.js"

echo "==> Activate semester ${SEMESTER}"
node "${SCRIPT_DIR}/activate_semester.js" --semester="${SEMESTER}"

echo ""
echo "Done. Restart the API to reload in-memory cache:"
echo "  ./deploy.sh --api"
echo "  # or locally: cd server && npm restart"
