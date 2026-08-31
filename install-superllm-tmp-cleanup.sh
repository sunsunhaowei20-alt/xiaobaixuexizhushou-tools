#!/bin/bash
# 安装超级大模型临时目录 7 天自动清理（cron 每天 03:17 执行）
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$BUNDLE/cleanup-superllm-tmp.sh"
LOG=/var/log/xiaobai-superllm-cleanup.log
CRON_MARK="# xiaobai-superllm-tmp-cleanup"
CRON_LINE="17 3 * * * $DEST >> $LOG 2>&1 $CRON_MARK"

echo "[$(date)] INSTALL_SUPERLLM_TMP_CLEANUP start"

mkdir -p "$BUNDLE"

if [ -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" ]; then
  cp -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" "$DEST"
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/cleanup-superllm-tmp.sh" -o "$DEST"
fi

chmod +x "$DEST"
sed -i 's/\r$//' "$DEST" 2>/dev/null || true

if ! crontab -l 2>/dev/null | grep -q "$CRON_MARK"; then
  (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
  echo "cron installed: daily 03:17, retention 7 days"
else
  crontab -l 2>/dev/null | grep -v "$CRON_MARK" | crontab - 2>/dev/null || true
  (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
  echo "cron updated: daily 03:17"
fi

echo "dry-run (list only, no delete):"
find /root/tmp/download /root/tmp/pdf /root/tmp/file \
  "$BUNDLE/services/superllm/tmp/download" \
  "$BUNDLE/services/superllm/tmp/pdf" \
  "$BUNDLE/services/superllm/tmp/file" \
  -maxdepth 1 -type f -mtime +7 2>/dev/null | head -n 20 || true

bash "$DEST" | tail -n 5
echo "[$(date)] INSTALL_SUPERLLM_TMP_CLEANUP_DONE"
