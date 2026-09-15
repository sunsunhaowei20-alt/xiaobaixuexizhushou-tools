#!/bin/bash
# 关闭 GitHub / cron / systemd 对工具的自动巡检与自愈（改用手动「修复 / 代码复制」）
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
mkdir -p "$BUNDLE"
date -Iseconds > "$BUNDLE/.manual-tools-only"
echo "XIAOBAI_AUTO_HEAL=0" > /etc/profile.d/xiaobai-tools-manual.sh 2>/dev/null || true

systemctl stop xiaobai-tools-watchdog.timer 2>/dev/null || true
systemctl disable xiaobai-tools-watchdog.timer 2>/dev/null || true
systemctl stop xiaobai-tools-boot.service 2>/dev/null || true
systemctl disable xiaobai-tools-boot.service 2>/dev/null || true

rm -f /etc/cron.d/xiaobai-tools 2>/dev/null || true
crontab -l 2>/dev/null | grep -v xiaobai-tools-watchdog | grep -v xiaobai-tools-daily-heal | crontab - 2>/dev/null || true

echo "=== DISABLE_AUTO_HEAL_DONE $(date) ==="
echo "说明：工具后端仅在首页点「修复/代码复制」或 OrcaTerm 粘贴命令时启动/修复。"
