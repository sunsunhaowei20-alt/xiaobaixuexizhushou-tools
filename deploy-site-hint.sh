#!/bin/bash
set -euo pipefail
DOMAIN=xiaobaixuexizhushou.cn
SITE=/www/wwwroot/$DOMAIN
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-hint-20260823/deploy-site-hint.zip}"

echo "=== $(date) DEPLOY_SITE_HINT ==="
rm -rf /tmp/site-hint /tmp/site-hint.zip
mkdir -p /tmp/site-hint
curl -fL --connect-timeout 30 --max-time 300 -o /tmp/site-hint.zip "$ZIP_URL"
unzip -o /tmp/site-hint.zip -d /tmp/site-hint
if [ -f /tmp/site-hint/index.html ]; then
  SRC=/tmp/site-hint
else
  SRC=$(find /tmp/site-hint -mindepth 1 -maxdepth 1 -type d | head -n 1)
fi
cp -a "$SRC"/. "$SITE"/
chown -R www:www "$SITE" || true
grep -n "浏览器打开" "$SITE/index.html" "$SITE/script.js" "$SITE/tools/superllm.html" | head
echo "=== $(date) DEPLOY_SITE_HINT_DONE ==="
