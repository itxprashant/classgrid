#!/usr/bin/env bash
# Build and deploy ClassGrid to a remote Linux host (nginx + systemd).
# - rsync static CRA bundle to ${REMOTE_WEB_DIR} (served by nginx)
# - rsync the Node API to ${REMOTE_API_DIR}, npm ci, restart systemd
#
# Usage:
#   ./deploy.sh                        # build + upload (static + API)
#   ./deploy.sh --setup                # first-time nginx + certbot + systemd, then deploy
#   ./deploy.sh --static               # SPA only
#   ./deploy.sh --api                  # API only (rsync server/, restart systemd)
#   ./deploy.sh --apk                  # upload dist/app/classgrid.apk to nginx web root
#
# SSH: uses ~/.ssh/config Host alias mydevclub by default (same as `ssh mydevclub`).
# Optional deploy.env: DEPLOY_SSH_HOST, DEPLOY_DOMAIN (see deploy.env.example).
# Legacy: DEPLOY_HOST + DEPLOY_USER + SSH_IDENTITY still supported.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Optional local overrides (gitignored). AZURE_* names kept as deprecated aliases.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/lib/deploy_ssh.sh"
load_deploy_env "${SCRIPT_DIR}"

DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-}}"

REMOTE_WEB_DIR="${REMOTE_WEB_DIR:-/var/www/classgrid}"
REMOTE_API_DIR="${REMOTE_API_DIR:-/opt/classgrid-api}"
API_ENV_DIR="${API_ENV_DIR:-/etc/classgrid}"
API_ENV_FILE="${API_ENV_DIR}/api.env"
API_PORT="${API_PORT:-4500}"

APK_SRC="${APK_SRC:-${SCRIPT_DIR}/dist/app/classgrid.apk}"
REMOTE_APK_PATH="${REMOTE_APK_PATH:-app/classgrid.apk}"

require_deploy_config() {
    require_deploy_ssh
}

setup_server() {
    require_deploy_config
    echo "Setting up nginx + certbot + classgrid-api on ${REMOTE}..."

    remote "sudo mkdir -p ${REMOTE_WEB_DIR} /var/www/letsencrypt ${REMOTE_API_DIR} ${REMOTE_API_DIR}/data ${API_ENV_DIR} \
        && sudo chown ${DEPLOY_USER}:${DEPLOY_USER} ${REMOTE_WEB_DIR} ${REMOTE_API_DIR} ${REMOTE_API_DIR}/data \
        && sudo chmod 750 ${API_ENV_DIR}"

    if ! remote "test -f ${API_ENV_FILE}"; then
        remote "sudo tee ${API_ENV_FILE} > /dev/null" <<EOF
# Created by deploy.sh — fill in OIDC/SESSION values before starting classgrid-api
NODE_ENV=production
PORT=${API_PORT}
OIDC_CLIENT_ID=
OIDC_CLIENT_SECRET=
OIDC_REDIRECT_URI=https://${DEPLOY_DOMAIN}/auth/callback
OIDC_DISCOVERY_URL=https://auth.devclub.in/api/oauth/.well-known/openid-configuration
OIDC_SCOPE=openid profile email kerberos hostel
SESSION_SECRET=
FRONTEND_ORIGIN=https://${DEPLOY_DOMAIN}
DATABASE_URL=postgresql://classgrid:PASSWORD@127.0.0.1:5432/classgrid
EOF
        remote "sudo chmod 640 ${API_ENV_FILE} && sudo chown root:${DEPLOY_USER} ${API_ENV_FILE}"
        echo "Created ${API_ENV_FILE} with placeholders. Edit it on the server before starting."
    fi

    remote "sudo tee /etc/nginx/sites-available/classgrid > /dev/null" <<EOF
# ClassGrid — static CRA SPA + Node API
# Public URL: https://${DEPLOY_DOMAIN}

server {
    listen 80;
    listen [::]:80;
    server_name ${DEPLOY_DOMAIN};

    root ${REMOTE_WEB_DIR};
    index index.html;

    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/letsencrypt;
        try_files \$uri =404;
    }

    location /auth/ {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ ^/app/classgrid.*\\.apk\$ {
        default_type application/vnd.android.package-archive;
        add_header Content-Disposition 'attachment; filename="classgrid.apk"' always;
        add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        add_header CDN-Cache-Control "no-store" always;
        add_header Cloudflare-CDN-Cache-Control "no-store" always;
        try_files \$uri =404;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /static/ {
        access_log off;
        add_header Cache-Control "public, max-age=31536000, immutable" always;
        try_files \$uri =404;
    }

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/javascript application/javascript application/json image/svg+xml font/woff2;
}
EOF

    remote "sudo ln -sf /etc/nginx/sites-available/classgrid /etc/nginx/sites-enabled/classgrid"
    remote "sudo /usr/sbin/nginx -t && sudo systemctl reload nginx"
    remote "sudo certbot --nginx -d ${DEPLOY_DOMAIN} --non-interactive --agree-tos --redirect"

    remote "sudo tee /etc/systemd/system/classgrid-api.service > /dev/null" <<EOF
[Unit]
Description=ClassGrid API (Node/Express)
After=network.target

[Service]
Type=simple
User=${DEPLOY_USER}
Group=${DEPLOY_USER}
WorkingDirectory=${REMOTE_API_DIR}
EnvironmentFile=${API_ENV_FILE}
ExecStart=/usr/bin/node ${REMOTE_API_DIR}/src/index.js
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    remote "sudo systemctl daemon-reload && sudo systemctl enable classgrid-api"

    echo "Server setup complete. Edit ${API_ENV_FILE} on the host before going live."
}

deploy_static() {
    echo "Building production bundle..."
    npm run build

    echo "Uploading static bundle to ${REMOTE}:${REMOTE_WEB_DIR}/ ..."
    # Protect hosted APK from --delete (not part of the CRA build output).
    rsync -avz --delete -e "$RSYNC_SSH" \
        --filter 'P app/' \
        build/ "${REMOTE}:${REMOTE_WEB_DIR}/"
}

ensure_nginx_apk_location() {
    local redirect_target="${APK_VERSIONED_NAME:-}"
    echo "Ensuring nginx APK location (no CDN cache) on ${REMOTE}..."
    remote "sudo python3 -" "$redirect_target" <<'PY'
import sys
from pathlib import Path
redirect_target = sys.argv[1] if len(sys.argv) > 1 else ''
path = Path('/etc/nginx/sites-available/classgrid')
text = path.read_text(encoding='utf-8')

serve_block = r'''    location ~ ^/app/classgrid.*\.apk$ {
        default_type application/vnd.android.package-archive;
        add_header Content-Disposition 'attachment; filename="classgrid.apk"' always;
        add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        add_header CDN-Cache-Control "no-store" always;
        add_header Cloudflare-CDN-Cache-Control "no-store" always;
        try_files $uri =404;
    }

'''

redirect_block = ''
if redirect_target:
    redirect_block = (
        '    location = /app/classgrid.apk {\n'
        f'        return 302 /app/{redirect_target};\n'
        '    }\n\n'
    )

# Drop legacy blocks from earlier patches.
import re
text = re.sub(
    r'\n    location = /app/classgrid\.apk \{[^}]+\}\n',
    '\n',
    text,
    flags=re.DOTALL,
)
text = re.sub(
    r'\n    location ~ \^/app/classgrid[^\n]+\n(?:        [^\n]+\n)+    \}\n',
    '\n',
    text,
)

combined = redirect_block + serve_block
if 'location ~ ^/app/classgrid' in text and redirect_target and f'/app/{redirect_target}' in text:
    print('nginx APK blocks already present')
elif '    location / {' in text:
    text = text.replace('    location / {', combined + '    location / {', 1)
    path.write_text(text, encoding='utf-8')
    print('updated nginx APK location blocks')
else:
    raise SystemExit('could not find insertion point in classgrid nginx config')
PY
    remote "sudo /usr/sbin/nginx -t && sudo systemctl reload nginx"
}

deploy_apk() {
    if [[ ! -f "$APK_SRC" ]]; then
        echo "APK not found: $APK_SRC" >&2
        echo "Build with: (cd app && flutter build apk --release)" >&2
        echo "Or run: ./scripts/release-android-apk.sh --build" >&2
        exit 1
    fi

    echo "Uploading APK to ${REMOTE}:${REMOTE_WEB_DIR}/${REMOTE_APK_PATH} ..."
    remote "mkdir -p ${REMOTE_WEB_DIR}/$(dirname "${REMOTE_APK_PATH}")"
    rsync -avz -e "$RSYNC_SSH" \
        "$APK_SRC" \
        "${REMOTE}:${REMOTE_WEB_DIR}/${REMOTE_APK_PATH}"

    if [[ -n "${APK_VERSIONED_NAME:-}" ]]; then
        local versioned_path="app/${APK_VERSIONED_NAME}"
        echo "Uploading versioned APK to ${REMOTE_WEB_DIR}/${versioned_path} ..."
        rsync -avz -e "$RSYNC_SSH" \
            "$APK_SRC" \
            "${REMOTE}:${REMOTE_WEB_DIR}/${versioned_path}"
        echo "Versioned APK: https://${DEPLOY_DOMAIN}/${versioned_path}"
    fi

    ensure_nginx_apk_location
    echo "APK live at https://${DEPLOY_DOMAIN}/${REMOTE_APK_PATH}"
}

deploy_api() {
    echo "Uploading API source to ${REMOTE}:${REMOTE_API_DIR}/ ..."
    echo "(No semester data import — use scripts/db/run_on_prod.sh for Postgres seed jobs.)"
    rsync -avz --delete \
        --exclude node_modules \
        --exclude data \
        --exclude .env \
        --exclude .env.* \
        -e "$RSYNC_SSH" \
        server/ "${REMOTE}:${REMOTE_API_DIR}/"

    echo "Installing API deps and restarting service..."
    remote "cd ${REMOTE_API_DIR} && npm ci --omit=dev && sudo systemctl restart classgrid-api && sudo systemctl status classgrid-api --no-pager -l | head -n 20"
}

deploy() {
    require_deploy_config
    deploy_static
    deploy_api
    echo "Deployed — https://${DEPLOY_DOMAIN}"
}

case "${1:-}" in
    --setup)
        setup_server
        deploy
        ;;
    --static)
        require_deploy_config
        deploy_static
        echo "Static deployed — https://${DEPLOY_DOMAIN}"
        ;;
    --api)
        require_deploy_config
        deploy_api
        echo "API deployed."
        ;;
    --apk)
        require_deploy_config
        deploy_apk
        ;;
    --help|-h)
        echo "Usage: $0 [--setup|--static|--api|--apk]"
        echo ""
        echo "Configure via deploy.env (optional) or environment:"
        echo "  DEPLOY_SSH_HOST   SSH config Host alias (default: mydevclub)"
        echo "  DEPLOY_DOMAIN     Public site hostname (default: classgrid.devclub.in)"
        echo "  API_PORT          Backend listen port (default: 4500)"
        echo "  APK_SRC           Local APK to upload (default: dist/app/classgrid.apk)"
        echo ""
        echo "Legacy explicit SSH: DEPLOY_HOST, DEPLOY_USER, SSH_IDENTITY"
        echo ""
        echo "  (no args)  build + rsync static and API (no DB imports)"
        echo "  --setup    configure nginx + certbot + systemd, then deploy"
        echo "  --static   only build and rsync the CRA bundle"
        echo "  --api      only rsync the API and restart classgrid-api (no DB imports)"
        echo "  --apk      only rsync the release APK to /app/classgrid.apk on the web host"
        ;;
    "")
        deploy
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac
