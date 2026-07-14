#!/usr/bin/env bash
# Extract unique campus room names from the room allotment PDF and copy to client bundles.
#
# Usage (from repo root):
#   ./scripts/generate_campus_rooms.sh
#
# Optional env:
#   ROOM_ALLOTMENT_PDF_URL       PDF URL (see extract_venue_map.py)
#   ROOM_ALLOTMENT_SOURCE_SEMESTER  Label in JSON (default: 2502)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUT="${REPO_ROOT}/data/campus_rooms.json"
mkdir -p "${REPO_ROOT}/data" "${REPO_ROOT}/public" "${REPO_ROOT}/app/assets"

python3 "${SCRIPT_DIR}/extract_venue_map.py" --rooms-list > "${OUT}"
cp "${OUT}" "${REPO_ROOT}/public/campus_rooms.json"
cp "${OUT}" "${REPO_ROOT}/app/assets/campus_rooms.json"

COUNT="$(python3 -c "import json; print(len(json.load(open('${OUT}'))['rooms']))")"
echo "Wrote ${COUNT} rooms to:"
echo "  ${OUT}"
echo "  ${REPO_ROOT}/public/campus_rooms.json"
echo "  ${REPO_ROOT}/app/assets/campus_rooms.json"
