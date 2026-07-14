#!/usr/bin/env bash
# Layout guardrails for panels, filter toolbars, and dashboard grids.
# See AGENTS.md "UI design ship gate" and docs/DESIGN.md "Layout & native controls".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0

report() {
    echo "check-ui-layout: $1" >&2
    fail=1
}

# Declaration lines only (skip comment-only lines).
css_props() {
    rg -N '^\s+[a-z-]+:' "$@" 2>/dev/null || true
}

block_has_overflow_hidden() {
    css_props /dev/stdin | rg -q 'overflow:\s*hidden'
}

check_blocks_in_files() {
    local block_pattern="$1"
    local message="$2"
    shift 2
    local files=("$@")

    for css_file in "${files[@]}"; do
        [[ -f "$css_file" ]] || continue
        local blocks
        blocks=$(rg -U -o "$block_pattern" "$css_file" 2>/dev/null || true)
        [[ -z "$blocks" ]] && continue
        if printf '%s\n' "$blocks" | block_has_overflow_hidden; then
            report "$message in $css_file"
        fi
    done
}

# --- Admin panel (regression guards for known failures) ---

ADMIN_CSS="src/pages/admin/admin.css"

if css_props "$ADMIN_CSS" | rg -q 'overflow:\s*hidden'; then
    report "admin.css must not use overflow:hidden (clips native <select> option menus)"
    css_props "$ADMIN_CSS" | rg 'overflow:\s*hidden' >&2 || true
fi

if ! css_props "$ADMIN_CSS" | rg -q 'grid-template-columns:\s*repeat\(4'; then
    report ".admin__priority must use an explicit 4-column grid (repeat(4, …))"
fi

if ! css_props "$ADMIN_CSS" | rg -q 'grid-template-columns:\s*repeat\(3'; then
    report ".admin__health .dl must use an explicit 3-column grid (repeat(3, …))"
fi

if css_props "$ADMIN_CSS" | rg -q 'auto-fit'; then
    report "admin.css must not use auto-fit grids (use explicit column counts for dashboard metrics)"
    css_props "$ADMIN_CSS" | rg 'auto-fit' >&2 || true
fi

# --- App-wide: filter toolbars / panel bodies must not clip native controls ---

mapfile -t CONTROL_FILES < <(rg -l '__controls' src --glob '*.css' 2>/dev/null || true)
check_blocks_in_files \
    '\.[a-zA-Z0-9_-]*__controls\s*\{[^}]*\}' \
    "*__controls must not use overflow:hidden (clips <select> / date inputs)" \
    "${CONTROL_FILES[@]}"

mapfile -t BODY_FILES < <(rg -l '__body' src/pages --glob '*.css' 2>/dev/null || true)
check_blocks_in_files \
    '\.[a-zA-Z0-9_-]*__body\s*\{[^}]*\}' \
    "*__body must not use overflow:hidden (use border-radius only; scroll on inner wrappers)" \
    "${BODY_FILES[@]}"

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi

echo "check-ui-layout: ok"
