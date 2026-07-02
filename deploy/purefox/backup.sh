#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
HOST_NGINX=/etc/nginx/conf.d/img.purefox.org.conf
TMP=""
cleanup() {
  if [ -n "$TMP" ]; then
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

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

if [ ! -f "$ROOT/.env" ]; then
  echo "Missing $ROOT/.env; create it from .env.example first." >&2
  exit 1
fi

DATA_DIR="${DATA_DIR:-$(env_value DATA_DIR)}"
BACKUP_DIR="${BACKUP_DIR:-$(env_value BACKUP_DIR)}"
DATA_DIR="${DATA_DIR:-../data}"
BACKUP_DIR="${BACKUP_DIR:-../backups}"
DATA_DIR_ABS="$(cd "$ROOT" && mkdir -p "$DATA_DIR" && cd "$DATA_DIR" && pwd)"
BACKUPS="$(cd "$ROOT" && mkdir -p "$BACKUP_DIR" && cd "$BACKUP_DIR" && pwd)"
TMP="$BACKUPS/.tmp-$TS"
ARCHIVE="$BACKUPS/image2api-$TS.tar.gz"

cd "$ROOT"
mkdir -p "$TMP" "$BACKUPS"
chmod 700 "$TMP" "$BACKUPS"

compose exec -T postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U postgres -d vivid_ai' > "$TMP/postgres.sql"

tmp_files=(postgres.sql)
if [ -r "$HOST_NGINX" ]; then
  cp "$HOST_NGINX" "$TMP/img.purefox.org.conf"
  tmp_files+=(img.purefox.org.conf)
fi

data_files=()
for dir in redis rustfs generated; do
  if [ -e "$DATA_DIR_ABS/$dir" ]; then
    data_files+=("$dir")
  fi
done

tar_args=(
  -C "$ROOT"
  .env
  docker-compose.yml
  frontend.Dockerfile
  frontend-http.conf.template
  nginx.img.purefox.org.conf
)
if [ "${#data_files[@]}" -gt 0 ]; then
  tar_args+=(-C "$DATA_DIR_ABS" "${data_files[@]}")
fi
tar_args+=(-C "$TMP" "${tmp_files[@]}")

tar -czf "$ARCHIVE" "${tar_args[@]}"

chmod 600 "$ARCHIVE"
echo "$ARCHIVE"
