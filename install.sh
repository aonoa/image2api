#!/usr/bin/env sh
# image2api — one-command install (Docker). Run from the repo root:
#   sh install.sh
# Brings up Postgres + Redis + RustFS + backend + frontend. The web container
# serves HTTP on WEB_PORT; put your own reverse proxy in front for domain/TLS.
set -e
cd "$(dirname "$0")"

# --- docker present? ---
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: 未安装 Docker。请先安装 Docker + Docker Compose。"
  exit 1
fi

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file .env "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --env-file .env "$@"
  else
    echo "ERROR: 未安装 Docker Compose。请先安装 Docker Compose。"
    exit 1
  fi
}

# --- env file ---
if [ ! -f .env ]; then
  echo "==> 生成 .env(从 .env.docker.example),请按提示编辑后重跑"
  cp .env.docker.example .env
  echo
  echo "    必填:POSTGRES_PASSWORD、S3_ACCESS_KEY、S3_SECRET_KEY"
  echo "    反代域名/TLS 请在外部 Nginx/Caddy 配置，并同步设置 CORS_ORIGINS / COOKIE_SECURE"
  echo "    编辑好后再次执行:  sh install.sh"
  exit 0
fi

require_env() {
  key="$1"
  val="$(grep -E "^${key}=" .env | tail -1 | cut -d= -f2-)"
  if [ -z "$val" ]; then
    echo "ERROR: .env 中缺少必填项: $key"
    exit 1
  fi
  case "$val" in
    change-me*|vividai|vividai-secret-change-me)
      echo "ERROR: .env 中 $key 仍是示例弱值，请改成强随机值。"
      exit 1
      ;;
  esac
}

require_env POSTGRES_PASSWORD
require_env S3_ACCESS_KEY
require_env S3_SECRET_KEY

# --- up ---
echo "==> docker compose --env-file .env up -d --build"
compose up -d --build

WEB_PORT_VAL="$(grep -E '^WEB_PORT=' .env | head -1 | cut -d= -f2-)"
echo
echo "完成。默认本机访问: http://localhost:${WEB_PORT_VAL:-2000}/"
echo "后端日志: docker compose --env-file .env logs -f backend"
echo "停止:     docker compose --env-file .env down"
