#!/usr/bin/env bash
# Build ClassGrid release APK, stage for deploy, and push to the production VM.
#
# Release workflow:
#   0. ./scripts/android-keystore-init.sh   # once — stable release signing (see docs/ANDROID_SIGNING.md)
#   1. ./scripts/bump-app-version.sh   # interactive pubspec + CHANGELOG bump
#   2. ./scripts/release-android-apk.sh --build
#
# Or manually: add "## [X.Y.Z] - date" to CHANGELOG.md and bump app/pubspec.yaml.
# By default the new release becomes "latest" only; users below minimum are still
# force-blocked, but users between minimum and latest see an optional update prompt.
# Pass --bump-minimum to raise the force-update floor to this release.
#
# Each release is also published as /app/classgrid-VERSION+BUILD.apk so Cloudflare
# cannot serve a stale binary at the stable /app/classgrid.apk path.
# GET /api/app/version downloadUrl points at the versioned filename.
#
# Usage (from repo root):
#   ./scripts/release-android-apk.sh              # stage APK, import version + changelog, deploy
#   ./scripts/release-android-apk.sh --build      # flutter build apk --release, then same
#   ./scripts/release-android-apk.sh --no-deploy  # stage + DB import only
#   ./scripts/release-android-apk.sh --apk-only     # skip ./deploy.sh --api (API already deployed)
#   ./scripts/release-android-apk.sh --bump-minimum # force-update everyone below this build
#
# SSH: ~/.ssh/config Host alias mydevclub (default). Optional deploy.env for DEPLOY_DOMAIN.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/deploy_ssh.sh"
load_deploy_env "${REPO_ROOT}"
DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-classgrid.devclub.in}}"

APK_PATH="${APK_PATH:-${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk}"
APK_STAGED="${APK_SRC:-${REPO_ROOT}/dist/app/classgrid.apk}"
APK_PUBLIC_URL=""

DO_BUILD=0
DO_DEPLOY=1
DO_DEPLOY_API=1
BUMP_MINIMUM=0
IMPORT_EXTRA_ARGS=()
RELEASE_FLAGS="${REPO_ROOT}/dist/app/release-flags.env"

for arg in "$@"; do
    case "$arg" in
        --build) DO_BUILD=1 ;;
        --no-deploy) DO_DEPLOY=0 ;;
        --apk-only) DO_DEPLOY=1; DO_DEPLOY_API=0 ;;
        --bump-minimum) BUMP_MINIMUM=1 ;;
        -h|--help)
            sed -n '2,26p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

if [[ -f "$RELEASE_FLAGS" ]]; then
    # shellcheck disable=SC1090
    source "$RELEASE_FLAGS"
    if [[ "${BUMP_MINIMUM:-0}" == "1" ]]; then
        BUMP_MINIMUM=1
    fi
    echo "==> release-flags.env: BUMP_MINIMUM=${BUMP_MINIMUM}"
fi

if [[ "$BUMP_MINIMUM" -eq 1 ]]; then
    IMPORT_EXTRA_ARGS+=(--bump-minimum)
fi

if [[ "$DO_BUILD" -eq 1 ]]; then
    KEY_PROPS="${APP_DIR}/android/key.properties"
    if [[ ! -f "$KEY_PROPS" ]]; then
        echo "Missing ${KEY_PROPS} — run ./scripts/android-keystore-init.sh first." >&2
        echo "See docs/ANDROID_SIGNING.md" >&2
        exit 1
    fi
    echo "==> flutter build apk --release (release keystore)"
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

if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "Missing ${CHANGELOG_FILE}. Add release notes before publishing." >&2
    exit 1
fi

echo "==> Validating CHANGELOG.md for v${VERSION_NAME}..."
node -e "
const { parseChangelogSection } = require('${REPO_ROOT}/scripts/lib/parse_changelog.js');
parseChangelogSection('${CHANGELOG_FILE}', '${VERSION_NAME}');
console.log('    Changelog section OK');
"

mkdir -p "$(dirname "$APK_STAGED")"
cp -f "$APK_PATH" "$APK_STAGED"

APK_VERSIONED_NAME="classgrid-${VERSION_NAME}+${BUILD_NUM}.apk"
APK_VERSIONED_STAGED="${REPO_ROOT}/dist/app/${APK_VERSIONED_NAME}"
cp -f "$APK_PATH" "$APK_VERSIONED_STAGED"
APK_PUBLIC_URL="https://${DEPLOY_DOMAIN}/app/${APK_VERSIONED_NAME}"

echo "==> Staged ${APK_STAGED} (${APK_SIZE}, pubspec ${VERSION})"
echo "==> Versioned ${APK_VERSIONED_STAGED}"

echo "==> Updating app_release_config + release history in Postgres..."
if can_deploy_ssh; then
    "${REPO_ROOT}/scripts/db/run_on_prod.sh" --minimal import_app_version.js \
        --version="${VERSION_NAME}" \
        --build="${BUILD_NUM}" \
        --url="${APK_PUBLIC_URL}" \
        --notes-file=CHANGELOG.md \
        ${IMPORT_EXTRA_ARGS+"${IMPORT_EXTRA_ARGS[@]}"}
else
    echo "    (ssh ${DEPLOY_SSH_HOST:-mydevclub} unavailable — using local DATABASE_URL)"
    (cd "${REPO_ROOT}/server" && NODE_PATH=./node_modules node ../scripts/db/import_app_version.js \
        --version="${VERSION_NAME}" \
        --build="${BUILD_NUM}" \
        --url="${APK_PUBLIC_URL}" \
        --notes-file="${CHANGELOG_FILE}" \
        ${IMPORT_EXTRA_ARGS+"${IMPORT_EXTRA_ARGS[@]}"})
fi

if [[ "$DO_DEPLOY" -eq 1 ]]; then
    if [[ "$DO_DEPLOY_API" -eq 1 ]]; then
        echo "==> Deploying API (restart picks up version cache)..."
        (cd "$REPO_ROOT" && ./deploy.sh --api)
    else
        echo "==> Skipped API deploy (--apk-only)."
    fi
    echo "==> Deploying APK (stable + versioned paths)..."
    (cd "$REPO_ROOT" && APK_VERSIONED_NAME="${APK_VERSIONED_NAME}" ./deploy.sh --apk)
else
    echo "    Skipped deploy (--no-deploy). Run:"
    echo "      ./deploy.sh --api && ./deploy.sh --apk"
fi

echo ""
echo "==> Done. Public APK URL:"
echo "    ${APK_PUBLIC_URL}"
if [[ -f "$RELEASE_FLAGS" ]]; then
    rm -f "$RELEASE_FLAGS"
fi
