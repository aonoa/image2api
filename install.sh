#!/usr/bin/env sh
# image2api — one-command install (Docker). Run from the repo root:
#   sh install.sh
# Brings up Postgres + Redis + RustFS + backend + frontend, and auto-issues a
# Let's Encrypt HTTPS certificate via the built-in acme.sh service.
set -e
cd "$(dirname "$0")"

# --- docker present? ---
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: 未安装 Docker。请先安装 Docker + Docker Compose。"
  exit 1
fi

# --- env file ---
if [ ! -f .env ]; then
  echo "==> 生成 .env(从 .env.docker.example),请按提示编辑后重跑"
  cp .env.docker.example .env
  echo
  echo "    必填:DOMAIN(你的域名)、ACME_EMAIL(证书邮箱)、POSTGRES_PASSWORD、S3_SECRET_KEY"
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

# --- backend binary (closed-source, shipped prebuilt) ---
if [ ! -f backend/bin/api ]; then
  echo "ERROR: 缺少 backend/bin/api(后端二进制)。"
  echo "       请从 Releases 下载 linux/amd64 的 api 放到 backend/bin/api 后重试。"
  exit 1
fi
chmod +x backend/bin/api 2>/dev/null || true

# --- up ---
echo "==> docker compose up -d --build"
docker compose up -d --build

DOMAIN_VAL="$(grep -E '^DOMAIN=' .env | head -1 | cut -d= -f2-)"
echo
echo "完成 ✅  打开 https://${DOMAIN_VAL:-<你的域名>}/"
echo "证书签发进度: docker compose logs -f acme"
echo "后端日志:     docker compose logs -f backend"
echo "停止:         docker compose down"
