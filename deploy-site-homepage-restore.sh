#!/bin/bash
# 从 site-fix 包恢复完整首页（13 工具侧栏 + script.js），不动各工具目录时可单独跑
set -eu
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
BASE=https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260929
PKG=site-fix-20260929.tar.gz
cd /tmp && rm -rf sf-home && mkdir sf-home && cd sf-home
if ! curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "$BASE/$PKG"; then
  curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
fi
tar -xzf p.tar.gz
cp -f index.html script.js auth.js config.js styles.css site-footer.js "$SITE/"
grep -c 'data-tool="choujiang"' "$SITE/index.html"
grep -c 'data-tool="saolei"' "$SITE/index.html"
echo SITE_HOMEPAGE_RESTORE_OK
