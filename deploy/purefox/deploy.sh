#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

env_value() {
  awk -v key="$1" '
    /^[[:space:]]*(#|$)/ { next }
    {
      line = $0
      eq = index(line, "=")
      if (!eq) next
      name = substr(line, 1, eq - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != key) next
      value = substr(line, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' .env
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file .env -p image2api -f docker-compose.yml "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --env-file .env -p image2api -f docker-compose.yml "$@"
  else
    echo "docker compose or docker-compose is required" >&2
    exit 127
  fi
}

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  cat >&2 <<'MSG'
Created deploy/purefox/.env from .env.example.
Edit .env and set strong POSTGRES_PASSWORD, S3_ACCESS_KEY, and S3_SECRET_KEY, then rerun this script.
MSG
  exit 1
fi

if grep -Eq '^(POSTGRES_PASSWORD|S3_ACCESS_KEY|S3_SECRET_KEY)=change-me' .env; then
  cat >&2 <<'MSG'
Refusing to deploy with placeholder secrets in deploy/purefox/.env.
Set strong POSTGRES_PASSWORD, S3_ACCESS_KEY, and S3_SECRET_KEY, then rerun this script.
MSG
  exit 1
fi

APP_DIR="${APP_DIR:-$(env_value APP_DIR)}"
DATA_DIR="${DATA_DIR:-$(env_value DATA_DIR)}"
BACKUP_DIR="${BACKUP_DIR:-$(env_value BACKUP_DIR)}"
APP_DIR="${APP_DIR:-../app}"
DATA_DIR="${DATA_DIR:-../data}"
BACKUP_DIR="${BACKUP_DIR:-../backups}"

if [ ! -d "$APP_DIR/backend" ] || [ ! -d "$APP_DIR/frontend" ]; then
  echo "Missing app source under $APP_DIR; expected backend/ and frontend/." >&2
  exit 1
fi

mkdir -p "$DATA_DIR/postgres" "$DATA_DIR/redis" "$DATA_DIR/rustfs" "$DATA_DIR/generated" "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
# rustfs/rustfs runs as uid/gid 10001 and must write to /data.
chown -R 10001:10001 "$DATA_DIR/rustfs"
chmod 750 "$DATA_DIR/rustfs"

compose up -d --build

cat <<'MSG'

Stack started.

If this is a new host, install the host Nginx config manually:
  sudo cp nginx.img.purefox.org.conf /etc/nginx/conf.d/img.purefox.org.conf
  sudo nginx -t
  sudo systemctl reload nginx

Verify:
  curl http://127.0.0.1:18087/health
  curl -k https://img.purefox.org/health
MSG
