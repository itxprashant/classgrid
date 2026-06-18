#!/usr/bin/env bash
# Smoke-test semester API endpoints after a refresh.
#
# Usage:
#   ./scripts/db/check_semester.sh                    # prod (DEPLOY_DOMAIN / classgrid.devclub.in)
#   ./scripts/db/check_semester.sh http://localhost:4000

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/deploy_ssh.sh"
load_deploy_env "${REPO_ROOT}"
DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-classgrid.devclub.in}}"

BASE="${1:-https://${DEPLOY_DOMAIN}}"

echo "==> GET ${BASE}/api/health"
curl -fsS "${BASE}/api/health" | python3 -m json.tool

echo ""
echo "==> GET ${BASE}/api/semester/meta"
curl -fsS "${BASE}/api/semester/meta" | python3 -m json.tool

echo ""
echo "==> GET ${BASE}/api/catalog/meta"
curl -fsS "${BASE}/api/catalog/meta" | python3 -m json.tool

echo ""
echo "==> GET ${BASE}/api/catalog/explorer (offered vs total)"
curl -fsS "${BASE}/api/catalog/explorer" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"explorer courses: {d.get('count', 0)} ({d.get('offeredCount', '?')} offered this sem)\")"

echo ""
echo "==> GET ${BASE}/api/extra-occupied (slot count)"
curl -fsS "${BASE}/api/extra-occupied" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"extra-occupied slots: {len(d.get('slots', []))}\")"

echo ""
echo "==> GET ${BASE}/api/semesters (archived + active count)"
curl -fsS "${BASE}/api/semesters" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('semesters',[]); print(f\"semesters in DB: {len(s)}\"); print('active:', next((x['code'] for x in s if x.get('isActive')), 'none'))"

echo ""
echo "OK"
