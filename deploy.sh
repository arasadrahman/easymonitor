#!/usr/bin/env bash

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/easymonitor}"
REPO_URL="${REPO_URL:-https://github.com/arasadrahman/easymonitor.git}"
BRANCH="${BRANCH:-main}"
APP_DOMAIN="${APP_DOMAIN:-${1:-}}"
TRAEFIK_NETWORK="${TRAEFIK_NETWORK:-traefik}"
TRAEFIK_ENTRYPOINT="${TRAEFIK_ENTRYPOINT:-websecure}"
TRAEFIK_CERTRESOLVER="${TRAEFIK_CERTRESOLVER:-letsencrypt}"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

random_secret() {
    openssl rand -hex 32
}

set_env() {
    local key="$1"
    local value="$2"
    local escaped

    escaped=$(printf '%s' "$value" | sed 's/[&|]/\\&/g')
    if grep -q "^${key}=" .env; then
        sed -i.bak "s|^${key}=.*|${key}=${escaped}|" .env
        rm -f .env.bak
    else
        printf '%s=%s\n' "$key" "$value" >> .env
    fi
}

[ "$(id -u)" -eq 0 ] || fail "Run with sudo: sudo -E ./deploy.sh monitor.example.com"
[ -n "$APP_DOMAIN" ] || fail "Domain required: sudo -E ./deploy.sh monitor.example.com"
[[ "$APP_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Invalid domain: $APP_DOMAIN"

command -v git >/dev/null || fail "git is required"
command -v docker >/dev/null || fail "Docker is not installed"
command -v openssl >/dev/null || fail "openssl is required"

if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    fail "Docker Compose is not installed"
fi

docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"
docker network inspect "$TRAEFIK_NETWORK" >/dev/null 2>&1 \
    || fail "Existing Traefik network not found: $TRAEFIK_NETWORK"

if [ ! -d "$DEPLOY_DIR/.git" ]; then
    [ ! -e "$DEPLOY_DIR" ] || [ -z "$(ls -A "$DEPLOY_DIR" 2>/dev/null)" ] \
        || fail "$DEPLOY_DIR exists and is not a Git checkout"
    mkdir -p "$(dirname "$DEPLOY_DIR")"
    git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$DEPLOY_DIR"
else
    git -C "$DEPLOY_DIR" fetch origin "$BRANCH"
    git -C "$DEPLOY_DIR" pull --ff-only origin "$BRANCH"
fi

cd "$DEPLOY_DIR"

if [ ! -f .env ]; then
    cp .env.example .env
    set_env DB_PASSWORD "$(random_secret)"
    set_env REDIS_PASSWORD "$(random_secret)"
fi

set_env APP_ENV production
set_env APP_DEBUG false
set_env APP_URL "https://${APP_DOMAIN}"
set_env APP_DOMAIN "$APP_DOMAIN"
set_env SESSION_SECURE_COOKIE true
set_env TRAEFIK_NETWORK "$TRAEFIK_NETWORK"
set_env TRAEFIK_ENTRYPOINT "$TRAEFIK_ENTRYPOINT"
set_env TRAEFIK_CERTRESOLVER "$TRAEFIK_CERTRESOLVER"
set_env COMPOSE_FILE "docker-compose.yml:docker-compose.production.yml"

chmod 600 .env

"${COMPOSE[@]}" -p easymonitor \
    -f docker-compose.yml \
    -f docker-compose.production.yml \
    up -d --build --remove-orphans

"${COMPOSE[@]}" -p easymonitor \
    -f docker-compose.yml \
    -f docker-compose.production.yml \
    exec -T php bash /var/www/html/docker/scripts/setup.sh

"${COMPOSE[@]}" -p easymonitor \
    -f docker-compose.yml \
    -f docker-compose.production.yml \
    up -d --force-recreate probe

echo "EasyMonitor deployed: https://${APP_DOMAIN}"
echo "Directory: ${DEPLOY_DIR}"
