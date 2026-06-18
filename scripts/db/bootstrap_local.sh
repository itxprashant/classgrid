#!/usr/bin/env bash
# First-time local Postgres setup: Docker, migrations, seed from legacy JSON.
#
# Usage (from repo root):
#   ./scripts/db/bootstrap_local.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="${REPO_ROOT}/server/db/db.env.example"

echo "==> Starting Postgres (docker compose)"
docker compose -f docker-compose.db.yml --env-file "$ENV_FILE" up -d

echo "==> Waiting for Postgres..."
sleep 3

echo "==> Applying migrations"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
export DATABASE_URL="${DATABASE_URL:-postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}}"
"${REPO_ROOT}/server/db/migrate.sh"

echo "==> Seeding semester data"
(cd "${REPO_ROOT}/server" && NODE_PATH=./node_modules node ../scripts/db/seed_from_files.js)

echo ""
echo "Done. Point server/.env at:"
echo "  DATABASE_URL=${DATABASE_URL}"
echo ""
echo "Then: cd server && npm start"
