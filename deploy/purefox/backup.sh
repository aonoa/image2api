#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUPS="$ROOT/backups"
TS="$(date +%Y%m%d-%H%M%S)"
TMP="$BACKUPS/.tmp-$TS"
ARCHIVE="$BACKUPS/image2api-$TS.tar.gz"
HOST_NGINX=/etc/nginx/conf.d/img.purefox.org.conf
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

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

mkdir -p "$TMP" "$BACKUPS"
chmod 700 "$TMP" "$BACKUPS"

if [ ! -f "$ROOT/.env" ]; then
  echo "Missing $ROOT/.env; create it from .env.example first." >&2
  exit 1
fi

cd "$ROOT"
compose exec -T \
  postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U postgres -d vivid_ai' \
  > "$TMP/postgres.sql"

tmp_files=(postgres.sql)
if [ -r "$HOST_NGINX" ]; then
  cp "$HOST_NGINX" "$TMP/img.purefox.org.conf"
  tmp_files+=(img.purefox.org.conf)
fi

tar -C "$ROOT" -czf "$ARCHIVE" \
  .env \
  docker-compose.yml \
  frontend.Dockerfile \
  frontend-http.conf.template \
  nginx.img.purefox.org.conf \
  data/redis \
  data/rustfs \
  data/generated \
  -C "$TMP" "${tmp_files[@]}"

chmod 600 "$ARCHIVE"
echo "$ARCHIVE"
