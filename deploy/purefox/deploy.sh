#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

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

mkdir -p data/postgres data/redis data/rustfs data/generated backups
chmod 700 backups
# rustfs/rustfs runs as uid/gid 10001 and must write to /data.
chown -R 10001:10001 data/rustfs
chmod 750 data/rustfs

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
