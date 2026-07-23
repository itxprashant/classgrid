#!/usr/bin/env bash
# Fetch IITD LDAP student lists and update production Postgres in one shot.
#
# Requires:
#   - IITD VPN (ldapweb.iitd.ac.in)
#   - SSH to prod (Host alias mydevclub, or deploy.env / DEPLOY_*)
#
# Usage (from repo root):
#   ./scripts/sync_student_enrollments.sh 2601
#   ./scripts/sync_student_enrollments.sh 2601 --no-deploy   # skip API restart
#   ./scripts/sync_student_enrollments.sh 2601 --dry-run     # fetch + parse counts only
#
# Steps:
#   1. Fetch gpaliases → data/ldap_exports/<semester>/
#   2. Import on the VM via run_on_prod.sh (replaces enrollments + rosters)
#   3. Restart classgrid-api so the enrollment cache reloads
#
# Lower-level (local DB / fetch-only): ./scripts/fetch_student_enrollments.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEMESTER="${1:-}"
shift || true

if [[ -z "$SEMESTER" || "$SEMESTER" == -* ]]; then
    echo "Usage: $0 <semester> [--no-deploy] [--dry-run]" >&2
    echo "Example: $0 2601" >&2
    exit 1
fi

NO_DEPLOY=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --no-deploy) NO_DEPLOY=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --no-deploy | --dry-run)" >&2
            exit 1
            ;;
    esac
done

echo "==> [1/3] Fetch LDAP enrollments for ${SEMESTER} (VPN required)"
"${REPO_ROOT}/scripts/fetch_student_enrollments.sh" "${SEMESTER}" --fetch-only

EXPORT_DIR="${REPO_ROOT}/data/ldap_exports/${SEMESTER}"
if [[ ! -f "${EXPORT_DIR}/studentCourses.json" || ! -f "${EXPORT_DIR}/courseStudents.json" ]]; then
    echo "Fetch did not write JSON under ${EXPORT_DIR}" >&2
    exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "==> [dry-run] Skipping prod import / deploy"
    node "${REPO_ROOT}/scripts/db/import_student_data.js" \
        "--semester=${SEMESTER}" --from-json --dry-run
    exit 0
fi

echo ""
echo "==> [2/3] Import ${SEMESTER} into production Postgres"
"${REPO_ROOT}/scripts/db/run_on_prod.sh" \
    import_student_data.js "--semester=${SEMESTER}" --from-json

if [[ "$NO_DEPLOY" -eq 1 ]]; then
    echo ""
    echo "Skipped API restart (--no-deploy). Run: ./deploy.sh --api"
    exit 0
fi

echo ""
echo "==> [3/3] Restart API cache"
"${REPO_ROOT}/deploy.sh" --api

echo ""
echo "Done. ${SEMESTER} enrollments updated on production."
echo "Verify: ./scripts/db/check_semester.sh"
