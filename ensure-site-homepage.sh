#!/bin/bash
# 若首页被旧包覆盖（缺 7/8 小工具或「修复」按钮），从 site-fix 包恢复
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SITE="${SITE:-/www/wwwroot/xiaobaixuexizhushou.cn}"
BASE="https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/site-fix-20260916"
PKG="site-fix-20260916.tar.gz"
LOG=/var/log/xiaobai-ensure-homepage.log

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

need_restore() {
  local idx="$SITE/index.html"
  [ -f "$idx" ] || return 0
  grep -q 'tools-fix-open' "$idx" 2>/dev/null || return 0
  grep -q 'data-tool="saolei"' "$idx" 2>/dev/null || return 0
  grep -q 'data-tool="game2048"' "$idx" 2>/dev/null || return 0
  grep -q 'bay-id">08' "$idx" 2>/dev/null || return 0
  return 1
}

if ! need_restore; then
  exit 0
fi

log "homepage stale — restoring from $PKG"
cd /tmp && rm -rf site-fix-auto && mkdir site-fix-auto && cd site-fix-auto
if ! curl -fL -o pkg.tar.gz "$BASE/$PKG"; then
  curl -fL -o pkg.tar.gz "https://ghfast.top/$BASE/$PKG" || {
    log "FATAL: download failed"
    exit 1
  }
fi
tar -xzf pkg.tar.gz

cp -f index.html script.js auth.js config.js styles.css "$SITE/"
mkdir -p "$SITE/tools/saolei/css" "$SITE/tools/saolei/js"
mkdir -p "$SITE/tools/2048/css" "$SITE/tools/2048/js"
mkdir -p "$SITE/tools/jizhang/img"
cp -f tools/saolei/index.html "$SITE/tools/saolei/"
cp -f tools/saolei/css/style.css "$SITE/tools/saolei/css/"
cp -f tools/saolei/js/minesweeper.js "$SITE/tools/saolei/js/"
cp -f tools/2048/index.html "$SITE/tools/2048/"
cp -f tools/2048/css/style.css "$SITE/tools/2048/css/"
cp -f tools/2048/js/game.js "$SITE/tools/2048/js/"
cp -f tools/jizhang/index.html "$SITE/tools/jizhang/"
cp -f tools/jizhang/img/bg-ledger.jpg "$SITE/tools/jizhang/img/" 2>/dev/null || true

chown www:www "$SITE/index.html" "$SITE/script.js" 2>/dev/null || true
log "done saolei=$(grep -c saolei "$SITE/index.html" || echo 0) fix_btn=$(grep -c tools-fix-open "$SITE/index.html" || echo 0)"
echo "ENSURE_HOMEPAGE_DONE"
