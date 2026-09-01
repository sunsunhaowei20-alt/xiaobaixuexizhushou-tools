#!/bin/bash
# 每 5 分钟巡检：健康检查 + 自愈（补 jar、修正 pm2 启动方式，不只 restart）
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
JDK=/opt/jdk-21
[ -x /opt/jdk21/bin/java ] && JDK=/opt/jdk21
LOG=/var/log/xiaobai-tools-watchdog.log
LOCK=/tmp/xiaobai-watchdog.lock

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

if [ -f "$LOCK" ]; then
  pid=$(cat "$LOCK" 2>/dev/null || echo "")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

check_url() {
  curl -sf -m 8 "$1" >/dev/null 2>&1
}

pm2_errored() {
  local name="$1"
  pm2 jlist 2>/dev/null | grep -q "\"name\":\"${name}\".*\"status\":\"errored\"" && return 0
  pm2 jlist 2>/dev/null | grep -q "\"name\":\"${name}\".*\"status\":\"stopped\"" && return 0
  return 1
}

ensure_runtime() {
  if [ ! -f "$BUNDLE/services/runtime.env" ]; then
    log "FATAL: missing runtime.env"
    return 1
  fi
  sed -i 's/\r$//' "$BUNDLE/services/runtime.env" 2>/dev/null || true
  set -a
  # shellcheck disable=SC1091
  source "$BUNDLE/services/runtime.env"
  set +a
}

ensure_superllm_jar() {
  local jar="$BUNDLE/services/superllm/yu-ai-agent.jar"
  local bak="$jar.bak"
  mkdir -p "$BUNDLE/services/superllm"
  if [ -f "$jar" ] && [ -s "$jar" ]; then
    cp -f "$jar" "$bak" 2>/dev/null || true
    return 0
  fi
  if [ -f "$bak" ] && [ -s "$bak" ]; then
    log "superllm jar missing — restore from backup"
    cp -f "$bak" "$jar"
    return 0
  fi
  log "superllm jar missing — downloading"
  for URL in \
    "https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar" \
    "https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar"
  do
    if curl -fL --connect-timeout 20 --max-time 600 -o "$jar.part" "$URL"; then
      mv -f "$jar.part" "$jar"
      cp -f "$jar" "$bak" 2>/dev/null || true
      log "superllm jar downloaded ok"
      return 0
    fi
    rm -f "$jar.part"
  done
  log "FATAL: cannot obtain superllm jar"
  return 1
}

start_xiaobai() {
  local XB="$BUNDLE/services/xiaobai-server"
  mkdir -p "$XB"
  cat > "$XB/start.sh" << 'EOF'
#!/bin/bash
cd /opt/xiaobai-tools/services/xiaobai-server
exec python3 -m uvicorn main:app --host 127.0.0.1 --port 8765
EOF
  chmod +x "$XB/start.sh"
  sed -i 's/\r$//' "$XB/start.sh" 2>/dev/null || true
  local base="${AI_BASE_URL%/}"; base="${base%/v1}"
  cat > "$XB/.env" <<EOF
AI_API_KEY=${AI_API_KEY}
AI_BASE_URL=${base}/v1
AI_MODEL=${AI_MODEL:-DeepSeek-V4-Pro}
HOST=127.0.0.1
PORT=${PORT_XIAOBAI:-8765}
SITE_ADMIN_PASS_HASH=d847ad955f2212645dd3053b773e6418ffe5822a0e93f6ab6f55e15de174d118
EOF
  pm2 delete xiaobai-api 2>/dev/null || true
  pm2 start "$XB/start.sh" --name xiaobai-api --cwd "$XB" --max-memory-restart 400M --restart-delay 3000
}

start_superllm() {
  local jar="$BUNDLE/services/superllm/yu-ai-agent.jar"
  ensure_superllm_jar || return 1
  [ -x "$JDK/bin/java" ] || { log "FATAL: java missing at $JDK"; return 1; }
  export JAVA_HOME="$JDK"
  export PATH="$JAVA_HOME/bin:$PATH"
  pm2 delete superllm 2>/dev/null || true
  pm2 start "$JDK/bin/java" --name superllm --cwd "$BUNDLE/services/superllm" \
    --max-memory-restart 800M --restart-delay 5000 --exp-backoff-restart-delay 100 \
    -- -jar "$jar" \
    --server.port=${PORT_SUPERLLM:-8123} \
    --spring.ai.openai.api-key="$AI_API_KEY" \
    --spring.ai.openai.base-url="$AI_BASE_URL" \
    --spring.ai.openai.chat.options.model="$AI_MODEL"
}

start_zhaiyue() {
  pm2 restart zhaiyue 2>/dev/null || pm2 start "$BUNDLE/services/zhaiyue/server.js" \
    --name zhaiyue --cwd "$BUNDLE/services/zhaiyue" --max-memory-restart 400M 2>/dev/null || true
}

ensure_runtime || exit 0
command -v pm2 >/dev/null 2>&1 || exit 0

fixed=0

if ! check_url "http://127.0.0.1:3000/" || pm2_errored "zhaiyue"; then
  log "heal zhaiyue"
  start_zhaiyue
  fixed=1
fi

if ! check_url "http://127.0.0.1:8765/api/health" || pm2_errored "xiaobai-api"; then
  log "heal xiaobai-api"
  start_xiaobai
  fixed=1
  sleep 3
fi

if ! check_url "http://127.0.0.1:8123/api/swagger-ui.html" || pm2_errored "superllm"; then
  log "heal superllm"
  start_superllm
  fixed=1
  sleep 8
fi

if [ "$fixed" = 1 ]; then
  pm2 save 2>/dev/null || true
  log "heal done — 8123=$(curl -s -o /dev/null -w '%{http_code}' -m 8 http://127.0.0.1:8123/api/swagger-ui.html || echo 000) 8765=$(curl -s -o /dev/null -w '%{http_code}' -m 8 http://127.0.0.1:8765/api/health || echo 000)"
fi
