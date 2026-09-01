#!/bin/bash
set -euo pipefail
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
XB=/opt/xiaobai-tools/services/xiaobai-server
#!/bin/bash
set -euo pipefail
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
XB=/opt/xiaobai-tools/services/xiaobai-server
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/patch-auth-guests-sync-20260901/patch-auth-guests-sync.zip}"
WORKDIR=/tmp/patch-auth-nodejs
rm -rf "$WORKDIR" /tmp/patch-auth-nodejs.zip
mkdir -p "$WORKDIR"
curl -fsSL -o /tmp/patch-auth-nodejs.zip "$ZIP_URL"
unzip -o /tmp/patch-auth-nodejs.zip -d "$WORKDIR"
if [ ! -f "$WORKDIR/site/auth.js" ]; then
  INNER=$(find "$WORKDIR" -type d -name site | head -n1)
  WORKDIR=$(dirname "$INNER")
fi
if [ ! -d "$SITE" ]; then SITE=$(ls -d /www/wwwroot/*xuexi* 2>/dev/null | head -n1); fi
if [ ! -d "$XB" ]; then XB=$(ls -d /opt/*/services/xiaobai-server 2>/dev/null | head -n1); fi
echo "SITE=$SITE XB=$XB"
cp -f "$WORKDIR/site/auth.js" "$SITE/auth.js"
cp -f "$WORKDIR/site/index.html" "$SITE/index.html"
mkdir -p "$XB/app/routers"
cp -f "$WORKDIR/xiaobai-server/main.py" "$XB/main.py"
cp -f "$WORKDIR/xiaobai-server/app/curated.py" "$XB/app/curated.py"
cp -f "$WORKDIR/xiaobai-server/app/config.py" "$XB/app/config.py"
cp -f "$WORKDIR/xiaobai-server/app/database.py" "$XB/app/database.py"
cp -f "$WORKDIR/xiaobai-server/app/routers/api.py" "$XB/app/routers/api.py"
cp -f "$WORKDIR/xiaobai-server/app/routers/site_auth.py" "$XB/app/routers/site_auth.py"
if [ -f /opt/xiaobai-tools/services/runtime.env ]; then set -a; . /opt/xiaobai-tools/services/runtime.env; set +a; fi
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
pm2 describe xiaobai-api >/dev/null 2>&1 && pm2 restart xiaobai-api --update-env || pm2 restart xiaobai --update-env || true
sleep 3
PORT=${PORT_XIAOBAI:-8765}
echo "=== generate nodejs ==="
curl -sS -m 25 -X POST "http://127.0.0.1:${PORT}/api/plans/generate" \
  -H "Content-Type: application/json" \
  -d '{"software_name":"nodejs","version":"22.14.0","platform":"windows"}' | head -c 600
echo
echo "=== guests ==="
curl -sS -m 10 "http://127.0.0.1:${PORT}/api/site-auth/guests" || true
echo
echo PATCH_DONE
