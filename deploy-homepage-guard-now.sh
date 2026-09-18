#!/bin/bash
# 恢复 13 工具首页 + 安装最新 ensure-site-homepage（不覆盖工具后端）
set -eu
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SITE=/www/wwwroot/xiaobaixuexizhushou.cn
BUNDLE=/opt/xiaobai-tools
BASE=https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260929
PKG=site-fix-20260929.tar.gz

echo "=== HOMEPAGE_GUARD $(date) ==="

mkdir -p "$BUNDLE"
cd /tmp && rm -rf sf-guard && mkdir sf-guard && cd sf-guard
curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "$BASE/$PKG" \
  || curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
tar -xzf p.tar.gz
cp -f index.html script.js auth.js config.js styles.css site-footer.js "$SITE/"
cp -f ensure-site-homepage.sh "$BUNDLE/" 2>/dev/null || true
chmod +x "$BUNDLE/ensure-site-homepage.sh" 2>/dev/null || true
for f in "$BUNDLE"/*.sh; do
  [ -f "$f" ] && sed -i 's/\r$//g' "$f"
done

grep -c 'data-tool="choujiang"' "$SITE/index.html"
grep -c 'tool-chip is-slot' "$SITE/index.html" || echo "is_slot=0"
bash "$BUNDLE/ensure-site-homepage.sh" || true
echo HOMEPAGE_GUARD_OK
