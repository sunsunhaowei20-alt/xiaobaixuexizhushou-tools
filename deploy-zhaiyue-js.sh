#!/bin/bash
# 更新线上 tools/zhaiyue.js（改进错误提示）
set -euo pipefail
DOMAIN=xiaobaixuexizhushou.cn
SITE=/www/wwwroot/$DOMAIN
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-zhaiyue-js-20260901/deploy-zhaiyue-js.zip}"

echo "=== $(date) DEPLOY_ZHAIYUE_JS ==="
rm -rf /tmp/zhaiyue-js /tmp/zhaiyue-js.zip
mkdir -p /tmp/zhaiyue-js
curl -fL --connect-timeout 30 --max-time 120 -o /tmp/zhaiyue-js.zip "$ZIP_URL"
unzip -o /tmp/zhaiyue-js.zip -d /tmp/zhaiyue-js
cp -f /tmp/zhaiyue-js/tools/zhaiyue.js "$SITE/tools/zhaiyue.js"
chown www:www "$SITE/tools/zhaiyue.js" || true
grep -n "connectionErrorMessage\|响应超时" "$SITE/tools/zhaiyue.js" | head -n 3
curl -sI -m 8 http://127.0.0.1:3000/ | head -n 3 || true
pm2 list | grep zhaiyue || true
echo "=== $(date) DEPLOY_ZHAIYUE_JS_DONE ==="
