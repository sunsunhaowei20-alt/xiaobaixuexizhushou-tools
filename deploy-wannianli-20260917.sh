#!/bin/bash
# 上线 09 万年历 + 首页（site-fix-20260917 Release 包）
set -eu
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SITE="${SITE:-/www/wwwroot/xiaobaixuexizhushou.cn}"
BASE="https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260917"
PKG="site-fix-20260917.tar.gz"

cd /tmp && rm -rf sf && mkdir sf && cd sf
if ! curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "$BASE/$PKG"; then
  curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
fi
tar -xzf p.tar.gz
cp -f index.html script.js auth.js config.js styles.css "$SITE/"
mkdir -p "$SITE/tools/wannianli"
cp -f tools/wannianli/index.html "$SITE/tools/wannianli/"
chown www:www "$SITE/index.html" "$SITE/script.js" "$SITE/tools/wannianli/index.html" 2>/dev/null || true
echo "wannianli_refs=$(grep -c wannianli "$SITE/index.html" || echo 0)"
echo "DEPLOY_WANLIANLI_OK $(date)"
