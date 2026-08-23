#!/bin/bash
# Install prebuilt superllm jar + start PM2; keep zhaiyue/xiaobai alive
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
if [ -x /opt/jdk-21/bin/java ]; then JDK=/opt/jdk-21
elif [ -x /opt/jdk21/bin/java ]; then JDK=/opt/jdk21
else JDK=/opt/jdk-21
fi
DOMAIN=xiaobaixuexizhushou.cn

echo "=== $(date) INSTALL_SUPERLLM_START ==="
echo "BUNDLE=$BUNDLE JDK=$JDK"
ls -la "$JDK/bin/java"
ls -la "$BUNDLE/services" || { echo "missing bundle"; exit 1; }

sed -i 's/\r$//' "$BUNDLE/services/runtime.env" || true
set -a
# shellcheck disable=SC1091
source "$BUNDLE/services/runtime.env"
set +a

export JAVA_HOME="$JDK"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$BUNDLE/services/superllm"
JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"

if [ ! -f "$JAR" ] || [ "$(stat -c%s "$JAR" 2>/dev/null || echo 0)" -lt 1000000 ]; then
  echo "downloading prebuilt jar..."
  rm -f "$JAR" "$JAR.part"
  OK=0
  for URL in \
    "https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar" \
    "https://mirror.ghproxy.com/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar" \
    "https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/yu-ai-agent.jar"
  do
    echo "GET $URL"
    if curl -fL --connect-timeout 30 --max-time 600 -o "$JAR.part" "$URL"; then
      mv "$JAR.part" "$JAR"
      OK=1
      break
    fi
    rm -f "$JAR.part"
  done
  if [ "$OK" != "1" ]; then
    echo "FATAL: jar download failed"
    exit 1
  fi
fi

echo "jar size=$(stat -c%s "$JAR") bytes"

pm2 delete superllm 2>/dev/null || true
pm2 start "$JAVA_HOME/bin/java" --name superllm -- \
  -Xms256m -Xmx768m \
  -jar "$JAR" \
  --server.port=${PORT_SUPERLLM:-8123} \
  --spring.ai.openai.api-key="$AI_API_KEY" \
  --spring.ai.openai.base-url="$AI_BASE_URL" \
  --spring.ai.openai.chat.options.model="$AI_MODEL"

# nginx proxy (context-path=/api)
SNIP=/www/server/panel/vhost/nginx/extension/$DOMAIN
mkdir -p "$SNIP"
cat > "$SNIP/tools_proxy.conf" << 'NGINX'
location /api/zhaiyue/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location /api/superllm/ {
    rewrite ^/api/superllm/api/(.*)$ /api/$1 break;
    rewrite ^/api/superllm/(.*)$ /api/$1 break;
    proxy_pass http://127.0.0.1:8123;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
    proxy_read_timeout 300s;
}
location /api/xiaobai/ {
    proxy_pass http://127.0.0.1:8765/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
NGINX

/www/server/nginx/sbin/nginx -t && /www/server/nginx/sbin/nginx -s reload
pm2 save

echo "waiting spring boot..."
for i in $(seq 1 24); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://127.0.0.1:8123/api/swagger-ui.html || echo 000)
  echo "try $i -> $code"
  case "$code" in 200|301|302) break ;; esac
  sleep 5
done

pm2 list
curl -sI -m 8 http://127.0.0.1:8123/api/swagger-ui.html | head -n 8 || true
curl -sI -m 8 https://127.0.0.1/api/superllm/swagger-ui.html -k | head -n 5 || true
echo "=== $(date) INSTALL_SUPERLLM_DONE ==="
