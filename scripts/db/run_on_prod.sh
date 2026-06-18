#!/usr/bin/env bash
# Run a scripts/db command on the production VM (DATABASE_URL there uses 127.0.0.1).
#
# Usage (from repo root):
#   ./scripts/db/run_on_prod.sh seed_from_files.js
#   ./scripts/db/run_on_prod.sh import_student_data.js --semester=2601
#   ./scripts/db/run_on_prod.sh -- ./scripts/db/refresh_semester.sh 2601
#
# SSH: ~/.ssh/config Host alias mydevclub (default). Optional deploy.env overrides.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/deploy_ssh.sh"
load_deploy_env "${REPO_ROOT}"
require_deploy_ssh

REMOTE_DIR="/tmp/classgrid-seed"

if [[ "${1:-}" == "--" ]]; then
    shift
    REMOTE_CMD="$*"
else
    SCRIPT_NAME="${1:?Usage: $0 <script.js> [args...]  OR  $0 -- <shell command>}"
    shift
    REMOTE_CMD="node scripts/db/${SCRIPT_NAME} $*"
fi

echo "==> Syncing seed inputs to ${REMOTE}:${REMOTE_DIR}"
remote "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}/{scripts/db,data,src,app,server/src,server/data}"

rsync -avz -e "$RSYNC_SSH" "${SCRIPT_DIR}/" "${REMOTE}:${REMOTE_DIR}/scripts/db/"
rsync -avz -e "$RSYNC_SSH" \
    "${REPO_ROOT}/server/src/parse_instructors.js" \
    "${REMOTE}:${REMOTE_DIR}/server/src/"
rsync -avz -e "$RSYNC_SSH" \
    "${REPO_ROOT}/data/academic_calendar.json" \
    "${REPO_ROOT}/data/extra_occupied.json" \
    "${REMOTE}:${REMOTE_DIR}/data/" 2>/dev/null || true

if [[ -f "${REPO_ROOT}/data/Courses_Offered.csv" ]]; then
    rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/data/Courses_Offered.csv" "${REMOTE}:${REMOTE_DIR}/data/"
fi

if [[ -f "${REPO_ROOT}/data/student_hostels.csv" ]]; then
    rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/data/student_hostels.csv" "${REMOTE}:${REMOTE_DIR}/data/"
fi

if [[ -d "${REPO_ROOT}/data/courses_offered_historical" ]]; then
    rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/data/courses_offered_historical/" "${REMOTE}:${REMOTE_DIR}/data/courses_offered_historical/"
fi

if [[ -d "${REPO_ROOT}/data/ldap_exports" ]]; then
    rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/data/ldap_exports/" "${REMOTE}:${REMOTE_DIR}/data/ldap_exports/"
fi

for f in courses.json studentCourses.json courseStudents.json; do
    if [[ -f "${REPO_ROOT}/src/${f}" ]]; then
        rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/src/${f}" "${REMOTE}:${REMOTE_DIR}/src/"
    fi
done

rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/app/pubspec.yaml" "${REMOTE}:${REMOTE_DIR}/app/" 2>/dev/null || true

rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/scripts/extract_venue_map.py" "${REMOTE}:${REMOTE_DIR}/scripts/"

echo "==> Running on VM: ${REMOTE_CMD}"
remote bash -lc "
  export DATABASE_URL=\$(grep '^DATABASE_URL=' /etc/classgrid/api.env | cut -d= -f2-)
  cd ${REMOTE_DIR}
  export NODE_PATH=/opt/classgrid-api/node_modules
  ${REMOTE_CMD}
"
