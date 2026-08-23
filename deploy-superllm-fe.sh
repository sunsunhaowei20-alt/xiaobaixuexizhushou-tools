#!/bin/bash
set -euo pipefail
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
TMP=/tmp/superllm-fe
rm -rf "$TMP"
mkdir -p "$TMP" "$SITE/apps/superllm"
URL=https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/superllm-jar-20260823/superllm-fe-dist.zip
curl -fL --connect-timeout 30 --max-time 180 -o /tmp/superllm-fe-dist.zip "$URL"
unzip -o /tmp/superllm-fe-dist.zip -d "$TMP"
# Windows zip may nest oddly; normalize
if [ -f "$TMP/index.html" ]; then
  SRC="$TMP"
elif [ -f "$TMP/dist/index.html" ]; then
  SRC="$TMP/dist"
else
  SRC=$(find "$TMP" -name index.html | head -n1 | xargs dirname)
fi
rm -rf "$SITE/apps/superllm"/*
cp -a "$SRC"/. "$SITE/apps/superllm/"
# also copy into deploy-upload mirror path if different site root used historically
if [ -d /www/wwwroot/xiaobaixuexizhushou.cn/apps ]; then
  mkdir -p /www/wwwroot/xiaobaixuexizhushou.cn/apps/superllm
  cp -a "$SRC"/. /www/wwwroot/xiaobaixuexizhushou.cn/apps/superllm/
fi
ls -la "$SITE/apps/superllm"
head -n 20 "$SITE/apps/superllm/index.html"
echo SUPERLLM_FE_DEPLOYED
