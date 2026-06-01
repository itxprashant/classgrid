#!/usr/bin/env bash
# Build ClassGrid release APK and upload to the shared Google Drive file.
# Keeps the public link in src/pages/Generator.jsx valid (same file id).
#
# Prereqs: flutter SDK, gdrive CLI (glotlabs) with `gdrive account list` showing your account.
#
# Usage (from repo root):
#   ./scripts/release-android-apk.sh           # upload APK, bump versions, deploy --api + --static
#   ./scripts/release-android-apk.sh --build   # flutter build apk --release, then same as above
#   ./scripts/release-android-apk.sh --no-deploy # upload + bump versions only (no deploy.sh)
#
# Env:
#   GOOGLE_DRIVE_APK_FILE_ID  default: 1_3fPAEBmWddY7HQ18oXbgiOwQSYJdr3I
#   APK_PATH                  default: app/build/app/outputs/flutter-apk/app-release.apk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"

GOOGLE_DRIVE_APK_FILE_ID="${GOOGLE_DRIVE_APK_FILE_ID:-1_3fPAEBmWddY7HQ18oXbgiOwQSYJdr3I}"
APK_PATH="${APK_PATH:-${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk}"

DO_BUILD=0
DO_DEPLOY=1
for arg in "$@"; do
    case "$arg" in
        --build) DO_BUILD=1 ;;
        --no-deploy) DO_DEPLOY=0 ;;
        -h|--help)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

if ! command -v gdrive >/dev/null 2>&1; then
    echo "gdrive CLI not found. Install from https://github.com/glotlabs/gdrive" >&2
    exit 1
fi

if ! gdrive account list 2>/dev/null | grep -q .; then
    echo "No gdrive account. Run: gdrive account add" >&2
    exit 1
fi

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
APK_DIR="$(dirname "$APK_PATH")"
APK_DRIVE_NAME="ClassGrid_${VERSION_NAME}.apk"
APK_NAMED="${APK_DIR}/${APK_DRIVE_NAME}"

cp -f "$APK_PATH" "$APK_NAMED"

echo "==> Uploading ${APK_NAMED} (${APK_SIZE}, pubspec ${VERSION})"
echo "    Drive file id: ${GOOGLE_DRIVE_APK_FILE_ID}"

gdrive files update "${GOOGLE_DRIVE_APK_FILE_ID}" "${APK_NAMED}"
gdrive files rename "${GOOGLE_DRIVE_APK_FILE_ID}" "${APK_DRIVE_NAME}"

ANDROID_VERSION_FILE="${REPO_ROOT}/server/data/android-version.json"
GENERATOR_JSX="${REPO_ROOT}/src/pages/Generator.jsx"
BUILD_NUM="${VERSION#*+}"
python3 - "$ANDROID_VERSION_FILE" "$GENERATOR_JSX" "$VERSION_NAME" "$BUILD_NUM" <<'PY'
import json
import re
import sys
from pathlib import Path

android_json = Path(sys.argv[1])
generator_jsx = Path(sys.argv[2])
version = sys.argv[3]
build = int(sys.argv[4])

data = json.loads(android_json.read_text(encoding="utf-8"))
android = data.setdefault("android", {})
android["version"] = version
android["build"] = build
android_json.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

jsx = generator_jsx.read_text(encoding="utf-8")
new_line = f"const ANDROID_APP_VERSION = '{version}';"
jsx_new, n = re.subn(
    r"const ANDROID_APP_VERSION = '[^']*';",
    new_line,
    jsx,
    count=1,
)
if n != 1:
    raise SystemExit(f"Could not update ANDROID_APP_VERSION in {generator_jsx}")
generator_jsx.write_text(jsx_new, encoding="utf-8")
print(f"{version}+{build}", end="")
PY
echo ""
echo "==> Updated ${ANDROID_VERSION_FILE}"
echo "==> Updated ${GENERATOR_JSX} (ANDROID_APP_VERSION=${VERSION_NAME})"

if [[ "$DO_DEPLOY" -eq 1 ]]; then
    echo "==> Deploying API (android-version.json)..."
    (cd "$REPO_ROOT" && ./deploy.sh --api)
    echo "==> Deploying static site (ANDROID_APP_VERSION label)..."
    (cd "$REPO_ROOT" && ./deploy.sh --static)
else
    echo "    Skipped deploy (--no-deploy). Run: ./deploy.sh --api && ./deploy.sh --static"
fi

echo ""
echo "==> Done. Public link (unchanged):"
echo "    https://drive.google.com/file/d/${GOOGLE_DRIVE_APK_FILE_ID}/view?usp=sharing"
