#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "错误: 未找到命令 '$1'"
    exit 1
  fi
}

read_secret() {
  local label="$1"
  local value=""

  while [[ -z "$value" ]]; do
    read -r -s -p "$label: " value
    echo
    if [[ -z "$value" ]]; then
      echo "错误: $label 不能为空"
    fi
  done

  printf '%s' "$value"
}

echo "CloudNote Cloudflare Workers 引导部署"
echo

require_command node
require_command npm

echo "[1/6] 安装项目依赖..."
npm install --package-lock=false

echo "[2/6] 执行 TypeScript 检查..."
npm run typecheck

echo "[3/6] 检查 Cloudflare 登录状态..."
if ! npx wrangler whoami >/dev/null 2>&1; then
  echo "未检测到 Cloudflare 登录状态，开始登录。"
  npx wrangler login
fi

echo "[4/6] 收集运行时密钥..."
read -r -p "ADMIN_USERNAME [admin]: " ADMIN_USERNAME
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="$(read_secret "ADMIN_PASSWORD")"
JWT_SECRET="$(node -e "const crypto = require('node:crypto'); console.log(crypto.randomBytes(32).toString('base64'));")"

echo "[5/6] 首次部署并自动创建 KV / R2 / D1 资源..."
npm run deploy

echo "[6/6] 初始化远程数据库并上传 Secrets..."
npx wrangler d1 execute cloudnote-db --remote --file=./schema.sql --yes

SECRETS_FILE="$(mktemp)"
trap 'rm -f "$SECRETS_FILE"' EXIT

ADMIN_USERNAME="$ADMIN_USERNAME" \
ADMIN_PASSWORD="$ADMIN_PASSWORD" \
JWT_SECRET="$JWT_SECRET" \
node -e "const fs = require('node:fs'); const file = process.argv[1]; const payload = { ADMIN_USERNAME: process.env.ADMIN_USERNAME, ADMIN_PASSWORD: process.env.ADMIN_PASSWORD, JWT_SECRET: process.env.JWT_SECRET }; fs.writeFileSync(file, JSON.stringify(payload), 'utf8');" \
  "$SECRETS_FILE"

npx wrangler secret bulk "$SECRETS_FILE"

echo
echo "部署完成。"
echo "本地开发前，请先复制 .dev.vars.example 为 .dev.vars 并填写真实密钥。"
echo "然后运行: npm run dev"
