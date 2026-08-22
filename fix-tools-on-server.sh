#!/bin/bash
set -euo pipefail

BUNDLE=/opt/xiaobai-tools
DOMAIN=xiaobaixuexizhushou.cn
SITE=/www/wwwroot/$DOMAIN
LOG=/tmp/fix_tools.log

exec > >(tee -a "$LOG") 2>&1
echo "[$(date)] fix tools start"

# Java 21 for superllm (standalone JDK, avoids package conflicts with Java 17)
JDK21=/opt/jdk-21
if [ ! -x "$JDK21/bin/java" ]; then
  echo "installing Temurin JDK 21 to $JDK21 ..."
  mkdir -p /opt
  rm -rf /tmp/jdk21.tgz /opt/jdk-21.tmp
  curl -fsSL "https://ghfast.top/https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz" -o /tmp/jdk21.tgz
  tar -xzf /tmp/jdk21.tgz -C /opt
  rm -rf "$JDK21"
  mv /opt/jdk-21* "$JDK21"
fi
export JAVA_HOME="$JDK21"
export PATH="$JAVA_HOME/bin:$PATH"
java -version

set -a
source "$BUNDLE/services/runtime.env"
set +a
export AI_API_KEY AI_BASE_URL AI_MODEL

# zhaiyue
pm2 delete zhaiyue 2>/dev/null || true
cd "$BUNDLE/services/zhaiyue"
cat > .env.local << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=$AI_BASE_URL
AI_MODEL=$AI_MODEL
EOF
PORT=${PORT_ZHAIYUE:-3000} HOSTNAME=127.0.0.1 NODE_ENV=production \
  pm2 start server.js --name zhaiyue --cwd "$BUNDLE/services/zhaiyue"
sleep 2
pm2 logs zhaiyue --lines 15 --nostream || true

# superllm jar
JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
if [ ! -f "$JAR" ]; then
  echo "building superllm jar with Java 21..."
  chmod +x "$BUNDLE/services/superllm-src/mvnw" 2>/dev/null || true
  cd "$BUNDLE/services/superllm-src"
  mvn -q -DskipTests package
  JAR=$(find "$BUNDLE/services/superllm-src/target" -name '*.jar' ! -name '*original*' | head -n 1)
  mkdir -p "$BUNDLE/services/superllm"
  cp "$JAR" "$BUNDLE/services/superllm/yu-ai-agent.jar"
fi

pm2 delete superllm 2>/dev/null || true
pm2 start "$JAVA_HOME/bin/java" --name superllm -- \
  -jar "$BUNDLE/services/superllm/yu-ai-agent.jar" \
  --server.port=${PORT_SUPERLLM:-8123} \
  --spring.ai.openai.api-key="$AI_API_KEY" \
  --spring.ai.openai.base-url="$AI_BASE_URL" \
  --spring.ai.openai.chat.options.model="$AI_MODEL"

# xiaobai api
pm2 delete xiaobai-api 2>/dev/null || true
cd "$BUNDLE/services/xiaobai-server"
python3 -m pip install -q -r requirements.txt 2>/dev/null || pip3 install -q -r requirements.txt
cat > "$BUNDLE/services/xiaobai-server/.env" << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=${AI_BASE_URL}/v1
AI_MODEL=$AI_MODEL
HOST=127.0.0.1
PORT=${PORT_XIAOBAI:-8765}
EOF
pm2 start "python3 -m uvicorn main:app --host 127.0.0.1 --port ${PORT_XIAOBAI:-8765}" \
  --name xiaobai-api --cwd "$BUNDLE/services/xiaobai-server" --interpreter bash

pm2 save

# nginx
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
    proxy_pass http://127.0.0.1:8123/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
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

location /apps/koutu/ {
    root /www/wwwroot/xiaobaixuexizhushou.cn;
    try_files $uri $uri/ /apps/koutu/index.html;
}

location /apps/superllm/ {
    root /www/wwwroot/xiaobaixuexizhushou.cn;
    try_files $uri $uri/ /apps/superllm/index.html;
}

location /apps/xiaobai/ {
    root /www/wwwroot/xiaobaixuexizhushou.cn;
    try_files $uri $uri/ /apps/xiaobai/index.html;
}
NGINX

/www/server/nginx/sbin/nginx -t
/www/server/nginx/sbin/nginx -s reload

sleep 5
pm2 list
curl -sI -m 8 http://127.0.0.1:3000/api/summarize -X OPTIONS | head -n 3 || true
echo "[$(date)] FIX_TOOLS_DONE"
