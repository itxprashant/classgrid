#!/usr/bin/env bash
# Fetch IITD LDAP student lists and optionally import into Postgres.
#
# LDAP (ldapweb.iitd.ac.in) is only reachable on IITD intranet or VPN.
# Typical workflow:
#
#   1. Connect to IITD VPN.
#   2. Fetch JSON locally (no DB needed):
#        ./scripts/fetch_student_enrollments.sh 2502 --fetch-only
#   3. Copy data/ldap_exports/2502/ to a machine with DATABASE_URL, then:
#        ./scripts/fetch_student_enrollments.sh 2502 --import
#      Or on prod VM:
#        ./scripts/db/run_on_prod.sh import_student_data.js --semester=2502 --from-json
#
# One-shot on VPN with local Postgres:
#   ./scripts/fetch_student_enrollments.sh 2502
#
# After import, restart API so enrollment cache reloads:
#   ./deploy.sh --api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEMESTER="${1:-2502}"
shift || true

MODE=both
DRY_RUN=""
for arg in "$@"; do
    case "$arg" in
        --fetch-only) MODE=fetch ;;
        --import) MODE=import ;;
        --dry-run) DRY_RUN="--dry-run" ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --fetch-only | --import | --dry-run)" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${DATABASE_URL:-}" && "$MODE" != fetch ]]; then
    if [[ -f "${REPO_ROOT}/server/.env" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "${REPO_ROOT}/server/.env"
        set +a
    fi
fi

IMPORTER=(node "${REPO_ROOT}/scripts/db/import_student_data.js" "--semester=${SEMESTER}")

case "$MODE" in
    fetch)
        echo "==> Fetch LDAP enrollments for ${SEMESTER} (VPN required)"
        "${IMPORTER[@]}" --fetch-only
        echo ""
        echo "JSON saved under data/ldap_exports/${SEMESTER}/"
        echo "Import later: ./scripts/fetch_student_enrollments.sh ${SEMESTER} --import"
        ;;
    import)
        if [[ -z "${DATABASE_URL:-}" ]]; then
            echo "DATABASE_URL is required for --import (export it or set in server/.env)" >&2
            exit 1
        fi
        echo "==> Import enrollments for ${SEMESTER} from data/ldap_exports/${SEMESTER}/"
        IMPORT_ARGS=(--from-json)
        if [[ -n "$DRY_RUN" ]]; then
            IMPORT_ARGS+=(--dry-run)
        fi
        "${IMPORTER[@]}" "${IMPORT_ARGS[@]}"
        ;;
    both)
        if [[ -z "${DATABASE_URL:-}" ]]; then
            echo "DATABASE_URL is required for fetch+import (export it or set in server/.env)" >&2
            echo "Or use: ./scripts/fetch_student_enrollments.sh ${SEMESTER} --fetch-only" >&2
            exit 1
        fi
        echo "==> Fetch LDAP + import Postgres for ${SEMESTER} (VPN required for fetch)"
        "${IMPORTER[@]}"
        ;;
esac

echo ""
echo "Reminder: semesters row must exist for ${SEMESTER} (FK)."
echo "If missing, run catalog/calendar import first, then re-run this script."
echo "After import: ./deploy.sh --api  (restart API cache)"
