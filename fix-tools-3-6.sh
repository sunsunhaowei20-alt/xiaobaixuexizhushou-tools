#!/bin/bash
# 修复 03 超级大模型 + 06 小白安装（互不影响，单步失败继续）
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
JDK=/opt/jdk-21
[ -x /opt/jdk21/bin/java ] && JDK=/opt/jdk21
LOG=/tmp/fix-tools-3-6.log
exec > >(tee -a "$LOG") 2>&1

echo "[$(date)] FIX_TOOLS_3_6 start"

if [ ! -f "$BUNDLE/services/runtime.env" ]; then
  echo "FATAL: missing $BUNDLE/services/runtime.env"
  exit 1
fi
sed -i 's/\r$//' "$BUNDLE/services/runtime.env" || true
set -a
# shellcheck disable=SC1091
source "$BUNDLE/services/runtime.env"
set +a

command -v pm2 >/dev/null 2>&1 || npm install -g pm2

# --- 06 小白安装 ---
fix_xiaobai() {
  echo "=== fix xiaobai-api ==="
  XB="$BUNDLE/services/xiaobai-server"
  mkdir -p "$XB"
  if [ -f "$XB/requirements.txt" ]; then
    pip3 install -q -r "$XB/requirements.txt" 2>/dev/null || pip3 install -q fastapi uvicorn sqlalchemy pydantic httpx python-dotenv 2>/dev/null || true
  else
    pip3 install -q fastapi uvicorn sqlalchemy pydantic httpx python-dotenv 2>/dev/null || true
  fi
  cat > "$XB/start.sh" << 'EOF'
#!/bin/bash
cd /opt/xiaobai-tools/services/xiaobai-server
exec python3 -m uvicorn main:app --host 127.0.0.1 --port 8765
EOF
  chmod +x "$XB/start.sh"
  sed -i 's/\r$//' "$XB/start.sh" || true
  BASE="${AI_BASE_URL%/}"; BASE="${BASE%/v1}"
  cat > "$XB/.env" <<EOF
AI_API_KEY=${AI_API_KEY}
AI_BASE_URL=${BASE}/v1
AI_MODEL=${AI_MODEL:-DeepSeek-V4-Pro}
HOST=127.0.0.1
PORT=${PORT_XIAOBAI:-8765}
SITE_ADMIN_PASS_HASH=d847ad955f2212645dd3053b773e6418ffe5822a0e93f6ab6f55e15de174d118
EOF
  pm2 delete xiaobai-api 2>/dev/null || true
  pm2 start "$XB/start.sh" --name xiaobai-api --cwd "$XB" --max-memory-restart 400M
  sleep 3
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://127.0.0.1:8765/api/health || echo 000)
  echo "xiaobai-api local HTTP=$code"
}

# --- 03 超级大模型 ---
fix_superllm() {
  echo "=== fix superllm ==="
  JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
  mkdir -p "$BUNDLE/services/superllm"
  if [ ! -f "$JAR" ]; then
    for URL in \
      "https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar" \
      "https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar"
    do
      curl -fL --connect-timeout 20 --max-time 300 -o "$JAR.part" "$URL" && mv "$JAR.part" "$JAR" && break
      rm -f "$JAR.part"
    done
  fi
  if [ ! -x "$JDK/bin/java" ] || [ ! -f "$JAR" ]; then
    echo "FATAL superllm: java or jar missing"
    return 1
  fi
  export JAVA_HOME="$JDK"
  export PATH="$JAVA_HOME/bin:$PATH"
  pm2 delete superllm 2>/dev/null || true
  pm2 start "$JDK/bin/java" --name superllm --cwd "$BUNDLE/services/superllm" --max-memory-restart 800M -- \
    -jar "$JAR" \
    --server.port=${PORT_SUPERLLM:-8123} \
    --spring.ai.openai.api-key="$AI_API_KEY" \
    --spring.ai.openai.base-url="$AI_BASE_URL" \
    --spring.ai.openai.chat.options.model="$AI_MODEL"
  sleep 10
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 15 http://127.0.0.1:8123/api/swagger-ui.html || echo 000)
  echo "superllm local HTTP=$code"
  if [ "$code" != "200" ] && [ "$code" != "301" ] && [ "$code" != "302" ]; then
    pm2 logs superllm --lines 25 --nostream 2>&1 || true
    return 1
  fi
}

fix_xiaobai || echo "WARN: xiaobai fix had issues"
fix_superllm || echo "WARN: superllm fix had issues"

pm2 save
/www/server/nginx/sbin/nginx -t 2>/dev/null && /www/server/nginx/sbin/nginx -s reload 2>/dev/null || true

# 备份 jar 防误删
JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
[ -f "$JAR" ] && cp -f "$JAR" "${JAR}.bak" 2>/dev/null || true

# 安装自愈 watchdog
WATCHDOG="$BUNDLE/tools-watchdog.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/tools-watchdog.sh" ]; then
  cp -f "$SCRIPT_DIR/tools-watchdog.sh" "$WATCHDOG"
elif [ -f "$WATCHDOG" ]; then
  :
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/tools-watchdog.sh" -o "$WATCHDOG" 2>/dev/null || true
fi
chmod +x "$WATCHDOG" 2>/dev/null || true
CRON_MARK="# xiaobai-tools-watchdog"
CRON_LINE="*/3 * * * * $WATCHDOG >> /var/log/xiaobai-tools-watchdog.log 2>&1 $CRON_MARK"
(crontab -l 2>/dev/null | grep -v "$CRON_MARK"; echo "$CRON_LINE") | crontab - 2>/dev/null || true

pm2 list
curl -s -o /dev/null -w "8123:%{http_code} " http://127.0.0.1:8123/api/swagger-ui.html || true
curl -s -o /dev/null -w "8765:%{http_code}\n" http://127.0.0.1:8765/api/health || true
echo "[$(date)] FIX_TOOLS_3_6_DONE"
