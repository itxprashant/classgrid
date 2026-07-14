#!/usr/bin/env bash
# Create a release keystore + android/key.properties for consistent APK signing.
#
# Run once from repo root. Back up the keystore and passwords somewhere safe
# (password manager / offline backup). Losing them means you cannot ship updates
# as the same app — users would have to uninstall and reinstall.
#
# Usage:
#   ./scripts/android-keystore-init.sh
#   ./scripts/android-keystore-init.sh --force   # replace existing keystore

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANDROID_DIR="${REPO_ROOT}/app/android"
KEYSTORE="${ANDROID_DIR}/classgrid-release.keystore"
PROPS="${ANDROID_DIR}/key.properties"
ALIAS="classgrid"

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help)
            sed -n '2,14p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if [[ -f "$KEYSTORE" || -f "$PROPS" ]] && [[ "$FORCE" -ne 1 ]]; then
    echo "Release keystore already exists:" >&2
    echo "  ${KEYSTORE}" >&2
    echo "  ${PROPS}" >&2
    echo "Re-run with --force to replace (breaks updates for existing installs)." >&2
    exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
    echo "keytool not found (install a JDK)." >&2
    exit 1
fi

STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
KEY_PASS="$STORE_PASS"

if [[ "$FORCE" -eq 1 ]]; then
    rm -f "$KEYSTORE" "$PROPS"
fi

echo "==> Generating release keystore (${ALIAS}, 10000-day validity)..."
keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=ClassGrid, OU=DevClub, O=IIT Delhi, L=New Delhi, ST=Delhi, C=IN"

cat > "$PROPS" <<EOF
storePassword=${STORE_PASS}
keyPassword=${KEY_PASS}
keyAlias=${ALIAS}
storeFile=classgrid-release.keystore
EOF
chmod 600 "$PROPS" "$KEYSTORE"

echo ""
echo "==> Created:"
echo "    ${KEYSTORE}"
echo "    ${PROPS}"
echo ""
echo "IMPORTANT:"
echo "  • Back up the keystore file and passwords now (1Password, encrypted drive, …)."
echo "  • All future ./scripts/release-android-apk.sh --build uses this key."
echo "  • After switching from debug-signed APKs, users must uninstall the old app once."
echo ""
echo "Store password (also in key.properties): ${STORE_PASS}"
