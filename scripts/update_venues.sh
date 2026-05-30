
#!/bin/bash
# Helper script to run the venue sync using the local virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -d "$ROOT_DIR/.venv" ]; then
    echo "Virtual environment not found. Setting it up..."
    python3 -m venv "$ROOT_DIR/.venv"
    "$ROOT_DIR/.venv/bin/pip" install PyPDF2
fi

"$ROOT_DIR/.venv/bin/python3" "$SCRIPT_DIR/sync_venues.py"
