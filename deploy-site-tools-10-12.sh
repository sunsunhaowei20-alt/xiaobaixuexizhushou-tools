#!/bin/bash
# 上线首页 + 工具 07-12（含 gongju-zongjie：方程/数独/五子棋）
set -eu
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SITE="${SITE:-/www/wwwroot/xiaobaixuexizhushou.cn}"
BASE="https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260918"
PKG="site-fix-20260918.tar.gz"

cd /tmp && rm -rf sf && mkdir sf && cd sf
if ! curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "$BASE/$PKG"; then
  curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
fi
tar -xzf p.tar.gz
cp -f index.html script.js auth.js config.js styles.css "$SITE/"
for d in saolei 2048 jizhang wannianli fangchengjisuan shudu wuziqi; do
  if [ -d "tools/$d" ]; then
    mkdir -p "$SITE/tools/$d"
    cp -a "tools/$d/." "$SITE/tools/$d/"
  fi
done
chown -R www:www "$SITE/index.html" "$SITE/script.js" "$SITE/tools" 2>/dev/null || true
echo "fangcheng=$(grep -c fangchengjisuan \"$SITE/index.html\" || echo 0)"
echo "shudu=$(grep -c 'data-tool=\"shudu\"' \"$SITE/index.html\" || echo 0)"
echo "wuziqi=$(grep -c wuziqi \"$SITE/index.html\" || echo 0)"
echo "DEPLOY_TOOLS_10_12_OK $(date)"
