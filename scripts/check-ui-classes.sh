#!/usr/bin/env bash
# Guardrails for ui.css form primitives (see AGENTS.md "Form fields (web)").
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0

if rg -q 'className=[^>]*field__|className=\{[^}]*field__|\.field__[a-z]' src/ 2>/dev/null; then
    echo "check-ui-classes: invalid BEM-style field classes (use FormField + field-label + .field on the control)" >&2
    rg -n 'className=[^>]*field__|className=\{[^}]*field__|\.field__[a-z]' src/ >&2 || true
    fail=1
fi

if rg -q '<label[^>]*className="field"' src/ 2>/dev/null; then
    echo "check-ui-classes: .field belongs on input/select/textarea, not on <label>" >&2
    rg -n '<label[^>]*className="field"' src/ >&2 || true
    fail=1
fi

if rg -q '<label[^>]*className="[^"]*mycal__form-row' src/ 2>/dev/null; then
    echo "check-ui-classes: use FormField instead of manual mycal__form-row labels" >&2
    rg -n '<label[^>]*className="[^"]*mycal__form-row' src/ >&2 || true
    fail=1
fi

if rg -q '<label[^>]*className="cdpolicy__form-row"' src/ 2>/dev/null; then
    echo "check-ui-classes: use FormField for course policy edit rows" >&2
    rg -n '<label[^>]*className="cdpolicy__form-row"' src/ >&2 || true
    fail=1
fi

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

echo "check-ui-classes: ok"
