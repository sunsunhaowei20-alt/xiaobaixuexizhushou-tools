#!/bin/bash
# 06 小白安装：同步 API 代码 + 重启 xiaobai-api（不碰首页 index.html）
set -eu
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SITE=/www/wwwroot/xiaobaixuexizhushou.cn
XB=/opt/xiaobai-tools/services/xiaobai-server
BUNDLE=/opt/xiaobai-tools
BASE=https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/xiaobai-api-20260918c
PKG=xiaobai-api-20260918c.tar.gz

echo "=== XIAOBAI_API_HEAL $(date) ==="

cd /tmp && rm -rf xb-api && mkdir xb-api && cd xb-api
curl -fL --connect-timeout 30 -m 120 -o p.tar.gz "$BASE/$PKG" \
  || curl -fL --connect-timeout 30 -m 120 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
tar -xzf p.tar.gz
mkdir -p "$XB"
shopt -s dotglob nullglob
for item in main.py requirements.txt app static admin; do
  if [ -e "$item" ]; then
    cp -a "$item" "$XB/"
  fi
done
shopt -u dotglob nullglob

if [ -f "$BUNDLE/services/runtime.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$BUNDLE/services/runtime.env"
  set +a
fi

pip3 install -q -r "$XB/requirements.txt" 2>/dev/null \
  || pip3 install -q fastapi uvicorn sqlalchemy pydantic httpx python-dotenv 2>/dev/null || true

cat > "$XB/start.sh" << 'EOF'
#!/bin/bash
cd /opt/xiaobai-tools/services/xiaobai-server
exec python3 -m uvicorn main:app --host 127.0.0.1 --port 8765
EOF
chmod +x "$XB/start.sh"
sed -i 's/\r$//' "$XB/start.sh" || true

if [ -f "$BUNDLE/services/runtime.env" ]; then
  XB_BASE="${AI_BASE_URL%/}"; XB_BASE="${XB_BASE%/v1}"
  printf "AI_API_KEY=%s\nAI_BASE_URL=%s/v1\nAI_MODEL=%s\nHOST=127.0.0.1\nPORT=%s\nSITE_ADMIN_PASS_HASH=d847ad955f2212645dd3053b773e6418ffe5822a0e93f6ab6f55e15de174d118\n" \
    "$AI_API_KEY" "$XB_BASE" "${AI_MODEL:-DeepSeek-V4-Pro}" "${PORT_XIAOBAI:-8765}" > "$XB/.env"
fi

cd "$XB"
python3 -c "from app.database import init_db; init_db(); print('db ok')"

pkill -9 -f "uvicorn main:app" 2>/dev/null || true
fuser -k 8765/tcp 2>/dev/null || true
sleep 2
pm2 delete xiaobai-api 2>/dev/null || true
pm2 start "$XB/start.sh" --name xiaobai-api --cwd "$XB" --max-memory-restart 400M
sleep 4

code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://127.0.0.1:8765/api/health || echo 000)
echo "xiaobai_local_health=$code"
auth_code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://127.0.0.1:8765/api/site-auth/guests || echo 000)
echo "site_auth_guests=$auth_code"
pm2 logs xiaobai-api --lines 15 --nostream 2>&1 || true

if [ -f "$BUNDLE/fix-tools-3-6.sh" ]; then
  bash "$BUNDLE/fix-tools-3-6.sh" || true
fi

echo XIAOBAI_API_HEAL_OK
