#!/bin/bash
set -euo pipefail
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
TMP=/tmp/superllm-fe
rm -rf "$TMP" && mkdir -p "$TMP" "$SITE/apps/superllm"
URL=https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/superllm-fe-dist.zip
curl -fL --connect-timeout 30 --max-time 180 -o /tmp/superllm-fe-dist.zip "$URL"
unzip -o /tmp/superllm-fe-dist.zip -d "$TMP"
rm -rf "$SITE/apps/superllm"/*
cp -a "$TMP"/. "$SITE/apps/superllm/"
ls -la "$SITE/apps/superllm" "$SITE/apps/superllm/assets" | head -n 40
grep -o 'createWebHistory[^)]*)' "$SITE/apps/superllm/assets/"index-*.js | head -n 3 || true
echo SUPERLLM_FE_DEPLOYED
