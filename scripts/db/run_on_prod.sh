#!/usr/bin/env bash
# Run a scripts/db command on the production VM (DATABASE_URL there uses 127.0.0.1).
#
# Usage (from repo root):
#   ./scripts/db/run_on_prod.sh import_student_hostels.js
#   ./scripts/db/run_on_prod.sh import_student_data.js --semester=2601 --from-json
#   ./scripts/db/run_on_prod.sh --with-data -- ./scripts/db/refresh_semester.sh 2601
#   ./scripts/db/run_on_prod.sh --minimal import_app_version.js --version=1.1.8 --build=8
#
# Default: sync scripts/db + only the input files needed for the target importer.
# --with-data  Sync all seed inputs (catalog CSV, historical CSVs, legacy JSON, …).
# --minimal    Scripts only — no data files (DB-only jobs like backfill_instructors.js).
#
# ./deploy.sh never runs importers or semester data sync — use this script instead.
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
WITH_DATA=0
MINIMAL=0
REMOTE_CMD=""
SCRIPT_ARGS=()
SCRIPT_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-data)
            WITH_DATA=1
            shift
            ;;
        --minimal)
            MINIMAL=1
            shift
            ;;
        --)
            shift
            REMOTE_CMD="$*"
            break
            ;;
        *)
            SCRIPT_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$REMOTE_CMD" ]]; then
    if [[ ${#SCRIPT_ARGS[@]} -eq 0 ]]; then
        echo "Usage: $0 [--with-data|--minimal] <script.js> [args...]  OR  $0 [--with-data] -- <shell command>" >&2
        exit 1
    fi
    SCRIPT_NAME="${SCRIPT_ARGS[0]}"
    REMOTE_CMD="node scripts/db/${SCRIPT_NAME}"
    if [[ ${#SCRIPT_ARGS[@]} -gt 1 ]]; then
        REMOTE_CMD+=" ${SCRIPT_ARGS[*]:1}"
    fi
fi

needs_full_data_sync() {
    if [[ "$WITH_DATA" -eq 1 ]]; then
        return 0
    fi
    case "${SCRIPT_NAME:-}" in
        seed_from_files.js) return 0 ;;
    esac
    case " ${REMOTE_CMD} " in
        *" refresh_semester.sh "*|*" seed_from_files.js "*) return 0 ;;
    esac
    return 1
}

if [[ "$MINIMAL" -eq 1 && "$WITH_DATA" -eq 1 ]]; then
    echo "Use either --minimal or --with-data, not both." >&2
    exit 1
fi

if needs_full_data_sync && [[ "$WITH_DATA" -eq 0 ]]; then
    echo "This job needs semester seed inputs. Re-run with --with-data." >&2
    exit 1
fi

remote "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}/{scripts/db,scripts/lib}"

if [[ "$WITH_DATA" -eq 1 ]]; then
    echo "==> Syncing full seed inputs to ${REMOTE}:${REMOTE_DIR}"
    remote "mkdir -p ${REMOTE_DIR}/{data,src,app,server/src,server/data,scripts}"
elif [[ "$MINIMAL" -eq 1 ]]; then
    echo "==> Syncing scripts only to ${REMOTE}:${REMOTE_DIR}"
else
    echo "==> Syncing scripts + importer inputs to ${REMOTE}:${REMOTE_DIR}"
    remote "mkdir -p ${REMOTE_DIR}/{data,src,app,server/src,scripts}"
fi

rsync -avz -e "$RSYNC_SSH" "${SCRIPT_DIR}/" "${REMOTE}:${REMOTE_DIR}/scripts/db/"
rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/scripts/lib/" "${REMOTE}:${REMOTE_DIR}/scripts/lib/"
rsync -avz -e "$RSYNC_SSH" "${REPO_ROOT}/CHANGELOG.md" "${REMOTE}:${REMOTE_DIR}/" 2>/dev/null || true

rsync_if_exists() {
    local src="$1"
    local dest="$2"
    if [[ -e "$src" ]]; then
        remote "mkdir -p $(dirname "${REMOTE_DIR}/${dest}")"
        rsync -avz -e "$RSYNC_SSH" "$src" "${REMOTE}:${REMOTE_DIR}/${dest}"
    fi
}

sync_full_seed_inputs() {
    rsync_if_exists "${REPO_ROOT}/server/src/parse_instructors.js" "server/src/parse_instructors.js"
    rsync_if_exists "${REPO_ROOT}/data/academic_calendar.json" "data/academic_calendar.json"
    rsync_if_exists "${REPO_ROOT}/data/extra_occupied.json" "data/extra_occupied.json"
    rsync_if_exists "${REPO_ROOT}/data/Courses_Offered.csv" "data/Courses_Offered.csv"
    rsync_if_exists "${REPO_ROOT}/data/student_hostels.csv" "data/student_hostels.csv"
    if [[ -d "${REPO_ROOT}/data/courses_offered_historical" ]]; then
        remote "mkdir -p ${REMOTE_DIR}/data/courses_offered_historical"
        rsync -avz -e "$RSYNC_SSH" \
            "${REPO_ROOT}/data/courses_offered_historical/" \
            "${REMOTE}:${REMOTE_DIR}/data/courses_offered_historical/"
    fi
    if [[ -d "${REPO_ROOT}/data/ldap_exports" ]]; then
        remote "mkdir -p ${REMOTE_DIR}/data/ldap_exports"
        rsync -avz -e "$RSYNC_SSH" \
            "${REPO_ROOT}/data/ldap_exports/" \
            "${REMOTE}:${REMOTE_DIR}/data/ldap_exports/"
    fi
    for f in courses.json studentCourses.json courseStudents.json; do
        rsync_if_exists "${REPO_ROOT}/src/${f}" "src/${f}"
    done
    rsync_if_exists "${REPO_ROOT}/app/pubspec.yaml" "app/pubspec.yaml"
    rsync_if_exists "${REPO_ROOT}/scripts/extract_venue_map.py" "scripts/extract_venue_map.py"
}

sync_script_inputs() {
    case "${SCRIPT_NAME:-}" in
        import_student_hostels.js)
            rsync_if_exists "${REPO_ROOT}/data/student_hostels.csv" "data/student_hostels.csv"
            ;;
        import_app_version.js)
            rsync_if_exists "${REPO_ROOT}/app/pubspec.yaml" "app/pubspec.yaml"
            ;;
        import_academic_calendar.js)
            rsync_if_exists "${REPO_ROOT}/data/academic_calendar.json" "data/academic_calendar.json"
            ;;
        import_catalog.js)
            rsync_if_exists "${REPO_ROOT}/data/Courses_Offered.csv" "data/Courses_Offered.csv"
            rsync_if_exists "${REPO_ROOT}/data/academic_calendar.json" "data/academic_calendar.json"
            ;;
        import_extra_occupied.js)
            rsync_if_exists "${REPO_ROOT}/data/extra_occupied.json" "data/extra_occupied.json"
            ;;
        import_historical_catalog.js)
            rsync_if_exists "${REPO_ROOT}/server/src/parse_instructors.js" "server/src/parse_instructors.js"
            if [[ -d "${REPO_ROOT}/data/courses_offered_historical" ]]; then
                remote "mkdir -p ${REMOTE_DIR}/data/courses_offered_historical"
                rsync -avz -e "$RSYNC_SSH" \
                    "${REPO_ROOT}/data/courses_offered_historical/" \
                    "${REMOTE}:${REMOTE_DIR}/data/courses_offered_historical/"
            fi
            ;;
        import_student_data.js)
            if [[ -d "${REPO_ROOT}/data/ldap_exports" ]]; then
                remote "mkdir -p ${REMOTE_DIR}/data/ldap_exports"
                rsync -avz -e "$RSYNC_SSH" \
                    "${REPO_ROOT}/data/ldap_exports/" \
                    "${REMOTE}:${REMOTE_DIR}/data/ldap_exports/"
            fi
            ;;
        sync_venues.js)
            rsync_if_exists "${REPO_ROOT}/scripts/extract_venue_map.py" "scripts/extract_venue_map.py"
            rsync_if_exists "${REPO_ROOT}/data/Room_Allotment_Chart.pdf" "data/Room_Allotment_Chart.pdf"
            rsync_if_exists "${REPO_ROOT}/data/venue_map.json" "data/venue_map.json"
            ;;
        backfill_instructors.js|activate_semester.js|refresh_semester_labels.js|check_semester.sh)
            rsync_if_exists "${REPO_ROOT}/server/src/parse_instructors.js" "server/src/parse_instructors.js"
            ;;
        *)
            if [[ -n "${SCRIPT_NAME:-}" ]]; then
                echo "No extra inputs registered for ${SCRIPT_NAME}; use --with-data if files are missing." >&2
            fi
            ;;
    esac
}

if [[ "$WITH_DATA" -eq 1 ]]; then
    sync_full_seed_inputs
elif [[ "$MINIMAL" -eq 0 ]]; then
    sync_script_inputs
fi

echo "==> Running on VM: ${REMOTE_CMD}"
remote bash -lc "
  export DATABASE_URL=\$(grep '^DATABASE_URL=' /etc/classgrid/api.env | cut -d= -f2-)
  cd ${REMOTE_DIR}
  export NODE_PATH=/opt/classgrid-api/node_modules
  ${REMOTE_CMD}
"
