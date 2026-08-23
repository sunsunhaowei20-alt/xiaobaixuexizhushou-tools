#!/bin/bash
# 快速重启摘阅/抠图/大模型/小白安装 后端服务（服务器重启后执行）
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
JDK21=/opt/jdk-21
DOMAIN=xiaobaixuexizhushou.cn

echo "[$(date)] restart tools"

if [ ! -f "$BUNDLE/services/runtime.env" ]; then
  echo "missing $BUNDLE/services/runtime.env — run full deploy first"
  exit 1
fi

set -a
source "$BUNDLE/services/runtime.env"
set +a

# zhaiyue (Next.js)
cd "$BUNDLE/services/zhaiyue"
if [ ! -d node_modules/next ]; then
  echo "installing zhaiyue node_modules..."
  npm install --omit=dev --no-audit --no-fund
fi
ZHAIYUE_BASE="${AI_BASE_URL%/}"
ZHAIYUE_BASE="${ZHAIYUE_BASE%/v1}"
cat > .env.local << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=${ZHAIYUE_BASE}/v1
AI_MODEL=$AI_MODEL
EOF
pm2 delete zhaiyue 2>/dev/null || true
PORT=${PORT_ZHAIYUE:-3000} HOSTNAME=127.0.0.1 NODE_ENV=production \
  pm2 start server.js --name zhaiyue --cwd "$BUNDLE/services/zhaiyue"

# xiaobai-api
cat > "$BUNDLE/services/xiaobai-server/start.sh" << 'EOF'
#!/bin/bash
cd /opt/xiaobai-tools/services/xiaobai-server
exec python3 -m uvicorn main:app --host 127.0.0.1 --port 8765
EOF
chmod +x "$BUNDLE/services/xiaobai-server/start.sh"
printf "AI_API_KEY=%s\nAI_BASE_URL=%s/v1\nAI_MODEL=%s\nHOST=127.0.0.1\nPORT=%s\n" \
  "$AI_API_KEY" "$AI_BASE_URL" "$AI_MODEL" "${PORT_XIAOBAI:-8765}" \
  > "$BUNDLE/services/xiaobai-server/.env"
pm2 delete xiaobai-api 2>/dev/null || true
pm2 start "$BUNDLE/services/xiaobai-server/start.sh" --name xiaobai-api --interpreter bash

# superllm
JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
if [ -f "$JAR" ] && [ -x "$JDK21/bin/java" ]; then
  pm2 delete superllm 2>/dev/null || true
  pm2 start "$JDK21/bin/java" --name superllm -- \
    -jar "$JAR" \
    --server.port=${PORT_SUPERLLM:-8123} \
    --spring.ai.openai.api-key="$AI_API_KEY" \
    --spring.ai.openai.base-url="$AI_BASE_URL" \
    --spring.ai.openai.chat.options.model="$AI_MODEL"
else
  echo "skip superllm: jar or JDK21 missing"
fi

pm2 save
/www/server/nginx/sbin/nginx -t
/www/server/nginx/sbin/nginx -s reload

sleep 3
pm2 list
curl -sI -m 8 http://127.0.0.1:3000/api/summarize -X OPTIONS | head -n 3 || true
echo "[$(date)] RESTART_TOOLS_DONE"
