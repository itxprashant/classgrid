#!/usr/bin/env bash
# Build and deploy ClassGrid to a remote Linux host (nginx + systemd).
# - rsync static CRA bundle to ${REMOTE_WEB_DIR} (served by nginx)
# - rsync the Node API to ${REMOTE_API_DIR}, npm ci, restart systemd
#
# Usage:
#   cp deploy.env.example deploy.env   # fill in host, SSH key, domain (deploy.env is gitignored)
#   ./deploy.sh                        # build + upload (static + API)
#   ./deploy.sh --setup                # first-time nginx + certbot + systemd, then deploy
#   ./deploy.sh --static               # SPA only
#   ./deploy.sh --api                  # API + data files only
#
# All deploy settings can also be exported in the shell:
#   DEPLOY_HOST=203.0.113.10 DEPLOY_USER=deploy SSH_IDENTITY=~/.ssh/id_ed25519 \
#   DEPLOY_DOMAIN=timetable.example.edu ./deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Optional local overrides (gitignored). AZURE_* names kept as deprecated aliases.
if [[ -f "${SCRIPT_DIR}/deploy.env" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/deploy.env"
fi

DEPLOY_HOST="${DEPLOY_HOST:-${AZURE_HOST:-}}"
DEPLOY_USER="${DEPLOY_USER:-${AZURE_USER:-}}"
SSH_IDENTITY="${SSH_IDENTITY:-${AZURE_KEY:-}}"
DEPLOY_DOMAIN="${DEPLOY_DOMAIN:-${DOMAIN:-}}"

REMOTE_WEB_DIR="${REMOTE_WEB_DIR:-/var/www/classgrid}"
REMOTE_API_DIR="${REMOTE_API_DIR:-/opt/classgrid-api}"
API_ENV_DIR="${API_ENV_DIR:-/etc/classgrid}"
API_ENV_FILE="${API_ENV_DIR}/api.env"
API_PORT="${API_PORT:-4500}"

STUDENT_DATA_SRC="${STUDENT_DATA_SRC:-${SCRIPT_DIR}/src/studentCourses.json}"
CATALOG_DATA_SRC="${CATALOG_DATA_SRC:-${SCRIPT_DIR}/src/courses.json}"
COURSE_STUDENTS_DATA_SRC="${COURSE_STUDENTS_DATA_SRC:-${SCRIPT_DIR}/src/courseStudents.json}"

SSH=()
RSYNC_SSH=""

require_deploy_config() {
    local missing=()
    [[ -n "$DEPLOY_HOST" ]] || missing+=(DEPLOY_HOST)
    [[ -n "$DEPLOY_USER" ]] || missing+=(DEPLOY_USER)
    [[ -n "$SSH_IDENTITY" ]] || missing+=(SSH_IDENTITY)
    [[ -n "$DEPLOY_DOMAIN" ]] || missing+=(DEPLOY_DOMAIN)

    if ((${#missing[@]} > 0)); then
        echo "Missing deploy settings: ${missing[*]}" >&2
        echo "Copy deploy.env.example to deploy.env and fill in values, or export the variables." >&2
        exit 1
    fi

    if [[ ! -f "$SSH_IDENTITY" ]]; then
        echo "SSH identity file not found: $SSH_IDENTITY" >&2
        exit 1
    fi

    SSH=(ssh -i "$SSH_IDENTITY" -o StrictHostKeyChecking=no)
    RSYNC_SSH="ssh -i ${SSH_IDENTITY} -o StrictHostKeyChecking=no"
}

remote() {
    "${SSH[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "$@"
}

setup_server() {
    require_deploy_config
    echo "Setting up nginx + certbot + classgrid-api on ${DEPLOY_HOST}..."

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
OIDC_SCOPE=openid profile email kerberos
SESSION_SECRET=
FRONTEND_ORIGIN=https://${DEPLOY_DOMAIN}
STUDENT_COURSES_PATH=${REMOTE_API_DIR}/data/studentCourses.json
CATALOG_PATH=${REMOTE_API_DIR}/data/courses.json
COURSE_STUDENTS_PATH=${REMOTE_API_DIR}/data/courseStudents.json
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

    echo "Uploading static bundle to ${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_WEB_DIR}/ ..."
    rsync -avz --delete -e "$RSYNC_SSH" build/ "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_WEB_DIR}/"
}

deploy_api() {
    echo "Uploading API source to ${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_API_DIR}/ ..."
    rsync -avz --delete \
        --exclude node_modules \
        --exclude data \
        --exclude .env \
        --exclude .env.* \
        -e "$RSYNC_SSH" \
        server/ "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_API_DIR}/"

    remote "mkdir -p ${REMOTE_API_DIR}/data"

    if [[ -f "$STUDENT_DATA_SRC" ]]; then
        echo "Uploading studentCourses data from ${STUDENT_DATA_SRC} ..."
        rsync -avz -e "$RSYNC_SSH" \
            "$STUDENT_DATA_SRC" \
            "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_API_DIR}/data/studentCourses.json"
    else
        echo "Skipping studentCourses upload (file not found: ${STUDENT_DATA_SRC})."
    fi

    if [[ -f "$CATALOG_DATA_SRC" ]]; then
        echo "Uploading course catalog from ${CATALOG_DATA_SRC} ..."
        rsync -avz -e "$RSYNC_SSH" \
            "$CATALOG_DATA_SRC" \
            "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_API_DIR}/data/courses.json"
    else
        echo "Skipping catalog upload (file not found: ${CATALOG_DATA_SRC})."
    fi

    if [[ -f "$COURSE_STUDENTS_DATA_SRC" ]]; then
        echo "Uploading courseStudents roster from ${COURSE_STUDENTS_DATA_SRC} ..."
        rsync -avz -e "$RSYNC_SSH" \
            "$COURSE_STUDENTS_DATA_SRC" \
            "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_API_DIR}/data/courseStudents.json"
    else
        echo "Skipping courseStudents upload (file not found: ${COURSE_STUDENTS_DATA_SRC})."
    fi

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
    --help|-h)
        echo "Usage: $0 [--setup|--static|--api]"
        echo ""
        echo "Configure via deploy.env (copy from deploy.env.example) or environment:"
        echo "  DEPLOY_HOST       SSH hostname or IP"
        echo "  DEPLOY_USER       SSH user"
        echo "  SSH_IDENTITY      Path to SSH private key"
        echo "  DEPLOY_DOMAIN     Public site hostname (nginx + certbot + OAuth redirect)"
        echo "  API_PORT          Backend listen port (default: 4500)"
        echo ""
        echo "  (no args)  build + rsync static and API"
        echo "  --setup    configure nginx + certbot + systemd, then deploy"
        echo "  --static   only build and rsync the CRA bundle"
        echo "  --api      only rsync the API and restart classgrid-api"
        ;;
    "")
        deploy
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac
