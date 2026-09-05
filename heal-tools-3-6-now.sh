#!/bin/bash
# 立即修复工具 3/6 并重装 cron 自愈（OrcaTerm 一行执行）
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BUNDLE=/opt/xiaobai-tools
mkdir -p "$BUNDLE"
BASE="https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main"
for f in fix-tools-3-6.sh tools-watchdog.sh enable-tools-always-on.sh; do
  curl -fsSL "$BASE/$f" -o "$BUNDLE/$f" || curl -fsSL "https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/$f" -o "$BUNDLE/$f"
  chmod +x "$BUNDLE/$f"
done
bash "$BUNDLE/fix-tools-3-6.sh"
bash "$BUNDLE/enable-tools-always-on.sh"
bash "$BUNDLE/tools-watchdog.sh"
if [ ! -f "$BUNDLE/.zero-touch-installed" ]; then
  curl -fsSL "https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/install-zero-touch-tools.sh" -o /tmp/install-zero-touch-tools.sh \
    && bash /tmp/install-zero-touch-tools.sh || true
fi
echo "=== VERIFY ==="
curl -s -o /dev/null -w "superllm:%{http_code} " http://127.0.0.1:8123/api/swagger-ui.html || true
curl -s -o /dev/null -w "xiaobai:%{http_code}\n" http://127.0.0.1:8765/api/health || true
pm2 list
crontab -l | grep xiaobai || true
echo "=== HEAL_NOW_DONE ==="
