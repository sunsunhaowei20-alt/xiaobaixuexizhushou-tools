#!/bin/bash
# 全站游客账号：部署 auth.js + site_auth API
set -euo pipefail
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
XB=/opt/xiaobai-tools/services/xiaobai-server
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/patch-auth-guests-sync-20260901c/patch-auth-guests-sync.zip}"
ROOT=/tmp/patch-auth-guests-sync

echo "=== $(date) DEPLOY_AUTH_GUESTS ==="
rm -rf "$ROOT" /tmp/patch-auth-guests-sync.zip
mkdir -p "$ROOT"
curl -fL --connect-timeout 30 --max-time 180 -o /tmp/patch-auth-guests-sync.zip "$ZIP_URL"
python3 - <<'PY'
import zipfile, os, shutil
root = "/tmp/patch-auth-guests-sync"
with zipfile.ZipFile("/tmp/patch-auth-guests-sync.zip") as z:
    z.extractall(root)
for name in list(os.listdir(root)):
    if "\\" in name:
        parts = name.split("\\")
        dst = os.path.join(root, *parts)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(os.path.join(root, name), dst)
PY

if [ ! -d "$ROOT/site" ]; then
  INNER=$(find "$ROOT" -type d -name site | head -n1)
  ROOT=$(dirname "$INNER")
fi

echo "ROOT=$ROOT SITE=$SITE XB=$XB"
cp -f "$ROOT/site/auth.js" "$SITE/auth.js"
cp -f "$ROOT/site/index.html" "$SITE/index.html"
mkdir -p "$XB/app/routers"
cp -f "$ROOT/xiaobai-server/main.py" "$XB/main.py"
cp -f "$ROOT/xiaobai-server/app/curated.py" "$XB/app/curated.py"
cp -f "$ROOT/xiaobai-server/app/config.py" "$XB/app/config.py"
cp -f "$ROOT/xiaobai-server/app/database.py" "$XB/app/database.py"
cp -f "$ROOT/xiaobai-server/app/routers/api.py" "$XB/app/routers/api.py"
cp -f "$ROOT/xiaobai-server/app/routers/site_auth.py" "$XB/app/routers/site_auth.py"

if [ -f /opt/xiaobai-tools/services/runtime.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /opt/xiaobai-tools/services/runtime.env
  set +a
fi
BASE="${AI_BASE_URL%/}"; BASE="${BASE%/v1}"
cat > "$XB/.env" <<EOF
AI_API_KEY=${AI_API_KEY}
AI_BASE_URL=${BASE}/v1
AI_MODEL=${AI_MODEL:-DeepSeek-V4-Pro}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-xiaobai2026}
SITE_ADMIN_PASS_HASH=d847ad955f2212645dd3053b773e6418ffe5822a0e93f6ab6f55e15de174d118
HOST=127.0.0.1
PORT=${PORT_XIAOBAI:-8765}
EOF

pm2 restart xiaobai-api --update-env || pm2 restart xiaobai --update-env
sleep 4
curl -sS -m 10 "http://127.0.0.1:${PORT_XIAOBAI:-8765}/api/site-auth/guests" || true
echo
echo "=== $(date) DEPLOY_AUTH_GUESTS_DONE ==="
