#!/bin/bash
# 只更新备案 footer 相关文件，不覆盖 index.html / script.js（避免首页退回旧 6 工具版）
set -eu
SITE=/www/wwwroot/xiaobaixuexizhushou.cn
BASE=https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260929
PKG=site-fix-20260929.tar.gz
cd /tmp && rm -rf sf-footer && mkdir sf-footer && cd sf-footer
if ! curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "$BASE/$PKG"; then
  curl -fL --connect-timeout 30 -m 300 -o p.tar.gz "https://ghfast.top/$BASE/$PKG"
fi
tar -xzf p.tar.gz
cp -f auth.js config.js styles.css site-footer.js "$SITE/"
cp -f tools/xiaobai-install.js "$SITE/tools/" 2>/dev/null || true
for d in saolei 2048 jizhang wannianli fangchengjisuan shudu wuziqi choujiang; do
  [ -d "tools/$d" ] || continue
  mkdir -p "$SITE/tools/$d"
  cp -a "tools/$d/." "$SITE/tools/$d/"
done
cp -f tools/koutu.html tools/koutu.js tools/zhaiyue.html tools/zhaiyue.js \
  tools/superllm.html tools/superllm.js tools/xiaobai-install.html tools/xiaobai-install.js \
  "$SITE/tools/" 2>/dev/null || true
grep -c "siteFooter" "$SITE/config.js"
grep -c "14098102000090" "$SITE/site-footer.js"
echo SITE_FOOTER_ONLY_OK
