#!/bin/bash
# 仅修复 03 超级大模型（Java 8123），可在宝塔【终端】或【计划任务-Shell】粘贴执行
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
DOMAIN=xiaobaixuexizhushou.cn

if [ -x /opt/jdk-21/bin/java ]; then
  JDK=/opt/jdk-21
elif [ -x /opt/jdk21/bin/java ]; then
  JDK=/opt/jdk21
else
  JDK=/opt/jdk-21
fi

echo "[$(date)] FIX_SUPERLLM_ONLY start"

if [ ! -f "$BUNDLE/services/runtime.env" ]; then
  echo "FATAL: missing $BUNDLE/services/runtime.env"
  exit 1
fi

sed -i 's/\r$//' "$BUNDLE/services/runtime.env" || true
set -a
# shellcheck disable=SC1091
source "$BUNDLE/services/runtime.env"
set +a

export JAVA_HOME="$JDK"
export PATH="$JAVA_HOME/bin:$PATH"

JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
mkdir -p "$BUNDLE/services/superllm"

if [ ! -f "$JAR" ]; then
  echo "jar missing — downloading..."
  for URL in \
    "https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar" \
    "https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar"
  do
    echo "try $URL"
    if curl -fL --connect-timeout 20 --max-time 300 -o "$JAR.part" "$URL"; then
      mv "$JAR.part" "$JAR"
      echo "downloaded jar ok"
      break
    fi
    rm -f "$JAR.part"
  done
fi

if [ ! -x "$JDK/bin/java" ]; then
  echo "FATAL: java not found at $JDK/bin/java"
  echo "Install JDK21 or fix path, then rerun."
  exit 1
fi

if [ ! -f "$JAR" ]; then
  echo "FATAL: jar still missing at $JAR"
  exit 1
fi

if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2
fi

pm2 delete superllm 2>/dev/null || true
pm2 start "$JDK/bin/java" --name superllm --max-memory-restart 800M -- \
  -jar "$JAR" \
  --server.port=${PORT_SUPERLLM:-8123} \
  --spring.ai.openai.api-key="$AI_API_KEY" \
  --spring.ai.openai.base-url="$AI_BASE_URL" \
  --spring.ai.openai.chat.options.model="$AI_MODEL"

pm2 save

sleep 8
code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://127.0.0.1:8123/api/swagger-ui.html || echo 000)
echo "local swagger HTTP=$code"
pm2 list

if [ "$code" = "200" ] || [ "$code" = "302" ] || [ "$code" = "301" ]; then
  echo "[$(date)] FIX_SUPERLLM_ONLY_DONE"
else
  echo "WARN: superllm may still be starting — check: pm2 logs superllm --lines 50"
  pm2 logs superllm --lines 30 --nostream || true
  exit 1
fi
