#!/usr/bin/env bash
# Shared SSH/rsync target for deploy.sh, scripts/db/run_on_prod.sh, and release-android-apk.sh.
#
# Usage:
#   load_deploy_env "$REPO_ROOT"          # optional deploy.env
#   source scripts/lib/deploy_ssh.sh
#   require_deploy_ssh                    # exit if ssh mydevclub (etc.) unreachable
#   remote 'whoami'
#   rsync -avz -e "$RSYNC_SSH" … "${REMOTE}:path"

load_deploy_env() {
    local repo_root="${1:?repo root required}"
    if [[ -f "${repo_root}/deploy.env" ]]; then
        # shellcheck disable=SC1091
        source "${repo_root}/deploy.env"
    fi
}

init_deploy_ssh() {
    DEPLOY_SSH_HOST="${DEPLOY_SSH_HOST:-mydevclub}"
    DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-classgrid.devclub.in}}"
    DEPLOY_HOST="${DEPLOY_HOST:-${AZURE_HOST:-}}"
    DEPLOY_USER="${DEPLOY_USER:-${AZURE_USER:-}}"
    SSH_IDENTITY="${SSH_IDENTITY:-${AZURE_KEY:-}}"

    if [[ -n "$DEPLOY_HOST" && -n "$DEPLOY_USER" && -n "$SSH_IDENTITY" ]]; then
        DEPLOY_SSH_MODE=legacy
        if [[ ! -f "$SSH_IDENTITY" ]]; then
            echo "SSH identity file not found: $SSH_IDENTITY" >&2
            exit 1
        fi
        SSH=(ssh -i "$SSH_IDENTITY" -o StrictHostKeyChecking=no)
        RSYNC_SSH="ssh -i ${SSH_IDENTITY} -o StrictHostKeyChecking=no"
        REMOTE="${DEPLOY_USER}@${DEPLOY_HOST}"
    else
        DEPLOY_SSH_MODE=alias
        SSH=(ssh "$DEPLOY_SSH_HOST")
        RSYNC_SSH="ssh"
        REMOTE="${DEPLOY_SSH_HOST}"
        if [[ -z "${DEPLOY_USER:-}" ]]; then
            DEPLOY_USER="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$DEPLOY_SSH_HOST" whoami)" || {
                echo "Could not resolve deploy user via: ssh ${DEPLOY_SSH_HOST} whoami" >&2
                echo "Set DEPLOY_USER in deploy.env or fix ~/.ssh/config for ${DEPLOY_SSH_HOST}." >&2
                exit 1
            }
        fi
        DEPLOY_HOST="${DEPLOY_HOST:-$DEPLOY_SSH_HOST}"
    fi
}

can_deploy_ssh() {
    local repo_root="${REPO_ROOT:-}"
    if [[ -n "$repo_root" ]]; then
        load_deploy_env "$repo_root"
    fi
    DEPLOY_SSH_HOST="${DEPLOY_SSH_HOST:-mydevclub}"
    DEPLOY_HOST="${DEPLOY_HOST:-${AZURE_HOST:-}}"
    DEPLOY_USER="${DEPLOY_USER:-${AZURE_USER:-}}"
    SSH_IDENTITY="${SSH_IDENTITY:-${AZURE_KEY:-}}"

    if [[ -n "$DEPLOY_HOST" && -n "$DEPLOY_USER" && -n "$SSH_IDENTITY" ]]; then
        ssh -i "$SSH_IDENTITY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            "${DEPLOY_USER}@${DEPLOY_HOST}" true 2>/dev/null
    else
        ssh -o BatchMode=yes -o ConnectTimeout=10 "$DEPLOY_SSH_HOST" true 2>/dev/null
    fi
}

require_deploy_ssh() {
    init_deploy_ssh

    if [[ -z "${DEPLOY_DOMAIN:-}" ]]; then
        echo "Missing DEPLOY_DOMAIN (public site hostname)." >&2
        exit 1
    fi

    if [[ "$DEPLOY_SSH_MODE" == alias ]]; then
        if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$DEPLOY_SSH_HOST" true 2>/dev/null; then
            echo "Cannot connect via: ssh ${DEPLOY_SSH_HOST}" >&2
            echo "Add a Host block to ~/.ssh/config (same as manual ssh ${DEPLOY_SSH_HOST})." >&2
            exit 1
        fi
    fi
}

remote() {
    if [[ "${DEPLOY_SSH_MODE:-alias}" == legacy ]]; then
        "${SSH[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "$@"
    else
        "${SSH[@]}" "$@"
    fi
}
