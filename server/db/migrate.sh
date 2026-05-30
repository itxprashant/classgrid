#!/usr/bin/env bash
# Apply pending SQL migrations in server/db/migrations/ against Postgres.
#
# Usage (from repo root or server/db/):
#   POSTGRES_HOST=127.0.0.1 POSTGRES_PASSWORD=... ./server/db/migrate.sh
#
# Or source /etc/classgrid/db.env on the VM first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="${SCRIPT_DIR}/migrations"

POSTGRES_HOST="${POSTGRES_HOST:-127.0.0.1}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-classgrid}"
POSTGRES_USER="${POSTGRES_USER:-classgrid}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"

export PGPASSWORD="${POSTGRES_PASSWORD}"

psql_base=(psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1)

docker_cmd() {
    if docker ps >/dev/null 2>&1; then
        docker "$@"
        return
    fi
    if sudo docker ps >/dev/null 2>&1; then
        sudo docker "$@"
        return
    fi
    echo "docker is not available" >&2
    exit 1
}

run_psql() {
    if command -v psql >/dev/null 2>&1; then
        "${psql_base[@]}" "$@"
        return
    fi
    if docker_cmd ps --format '{{.Names}}' | grep -qx classgrid-postgres; then
        docker_cmd exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" classgrid-postgres \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 "$@"
        return
    fi
    echo "psql not found and classgrid-postgres container is not running" >&2
    exit 1
}

run_sql_file() {
    local file="$1"
    if command -v psql >/dev/null 2>&1; then
        "${psql_base[@]}" -f "${file}"
        return
    fi
    if docker_cmd ps --format '{{.Names}}' | grep -qx classgrid-postgres; then
        docker_cmd exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" classgrid-postgres \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 \
            < "${file}"
        return
    fi
    echo "psql not found and classgrid-postgres container is not running" >&2
    exit 1
}

echo "[migrate] ensuring schema_migrations table exists..."
run_psql -c "CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);"

shopt -s nullglob
files=("${MIGRATIONS_DIR}"/*.sql)
if ((${#files[@]} == 0)); then
    echo "[migrate] no migration files in ${MIGRATIONS_DIR}"
    exit 0
fi

for file in "${files[@]}"; do
    version="$(basename "${file}")"
    applied="$(run_psql -tAc "SELECT 1 FROM schema_migrations WHERE version = '${version}'" 2>/dev/null || echo "")"
    if [[ "${applied}" == "1" ]]; then
        echo "[migrate] skip ${version} (already applied)"
        continue
    fi
    echo "[migrate] applying ${version}..."
    run_sql_file "${file}"
    run_psql -c "INSERT INTO schema_migrations (version) VALUES ('${version}');"
    echo "[migrate] applied ${version}"
done

echo "[migrate] done."
