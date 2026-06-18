#!/usr/bin/env bash
# Build ClassGrid release APK, stage for deploy, and push to the production VM.
#
# Each release is also published as /app/classgrid-VERSION+BUILD.apk so Cloudflare
# cannot serve a stale binary at the stable /app/classgrid.apk path.
# GET /api/app/version downloadUrl points at the versioned filename.
#
# Usage (from repo root):
#   ./scripts/release-android-apk.sh           # stage APK, bump DB version, deploy --api --apk
#   ./scripts/release-android-apk.sh --build   # flutter build apk --release, then same as above
#   ./scripts/release-android-apk.sh --no-deploy # stage + bump DB version only (no deploy.sh)
#
# SSH: ~/.ssh/config Host alias mydevclub (default). Optional deploy.env for DEPLOY_DOMAIN.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/deploy_ssh.sh"
load_deploy_env "${REPO_ROOT}"
DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-classgrid.devclub.in}}"

APK_PATH="${APK_PATH:-${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk}"
APK_STAGED="${APK_SRC:-${REPO_ROOT}/dist/app/classgrid.apk}"
APK_PUBLIC_URL=""

DO_BUILD=0
DO_DEPLOY=1
for arg in "$@"; do
    case "$arg" in
        --build) DO_BUILD=1 ;;
        --no-deploy) DO_DEPLOY=0 ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

if [[ "$DO_BUILD" -eq 1 ]]; then
    echo "==> flutter build apk --release"
    (cd "$APP_DIR" && flutter build apk --release)
fi

if [[ ! -f "$APK_PATH" ]]; then
    echo "APK not found: $APK_PATH" >&2
    exit 1
fi

APK_SIZE="$(du -h "$APK_PATH" | cut -f1)"
VERSION="$(grep -E '^version:' "${APP_DIR}/pubspec.yaml" | awk '{print $2}')"
VERSION_NAME="${VERSION%%+*}"
BUILD_NUM="${VERSION#*+}"

mkdir -p "$(dirname "$APK_STAGED")"
cp -f "$APK_PATH" "$APK_STAGED"

APK_VERSIONED_NAME="classgrid-${VERSION_NAME}+${BUILD_NUM}.apk"
APK_VERSIONED_STAGED="${REPO_ROOT}/dist/app/${APK_VERSIONED_NAME}"
cp -f "$APK_PATH" "$APK_VERSIONED_STAGED"
APK_PUBLIC_URL="https://${DEPLOY_DOMAIN}/app/${APK_VERSIONED_NAME}"

echo "==> Staged ${APK_STAGED} (${APK_SIZE}, pubspec ${VERSION})"
echo "==> Versioned ${APK_VERSIONED_STAGED}"

echo "==> Updating app_release_config in Postgres..."
if can_deploy_ssh; then
    "${REPO_ROOT}/scripts/db/run_on_prod.sh" import_app_version.js \
        --version="${VERSION_NAME}" \
        --build="${BUILD_NUM}" \
        --url="${APK_PUBLIC_URL}"
else
    echo "    (ssh ${DEPLOY_SSH_HOST:-mydevclub} unavailable — using local DATABASE_URL)"
    (cd "${REPO_ROOT}/server" && NODE_PATH=./node_modules node ../scripts/db/import_app_version.js \
        --version="${VERSION_NAME}" \
        --build="${BUILD_NUM}" \
        --url="${APK_PUBLIC_URL}")
fi

if [[ "$DO_DEPLOY" -eq 1 ]]; then
    echo "==> Deploying API (restart picks up version cache)..."
    (cd "$REPO_ROOT" && ./deploy.sh --api)
    echo "==> Deploying APK (stable + versioned paths)..."
    (cd "$REPO_ROOT" && APK_VERSIONED_NAME="${APK_VERSIONED_NAME}" ./deploy.sh --apk)
else
    echo "    Skipped deploy (--no-deploy). Run:"
    echo "      ./deploy.sh --api && ./deploy.sh --apk"
fi

echo ""
echo "==> Done. Public APK URL:"
echo "    ${APK_PUBLIC_URL}"
