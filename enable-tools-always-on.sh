#!/bin/bash
# 一次性：自愈 watchdog + 开机自启 + 每日预防性检查
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "ENABLE_TOOLS_ALWAYS_ON start"
mkdir -p "$BUNDLE"

# 1) 先完整修复一次（正确 pm2 启动 + jar 备份）
if [ -f "$SCRIPT_DIR/fix-tools-3-6.sh" ]; then
  bash "$SCRIPT_DIR/fix-tools-3-6.sh" || true
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/fix-tools-3-6.sh" \
    -o /tmp/fix-tools-3-6.sh
  bash /tmp/fix-tools-3-6.sh || true
fi

# 2) 安装自愈 watchdog（比单纯 restart 强）
WATCHDOG="$BUNDLE/tools-watchdog.sh"
if [ -f "$SCRIPT_DIR/tools-watchdog.sh" ]; then
  cp -f "$SCRIPT_DIR/tools-watchdog.sh" "$WATCHDOG"
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/tools-watchdog.sh" \
    -o "$WATCHDOG"
fi
chmod +x "$WATCHDOG"

# 3) pm2 持久化 + 开机自启
pm2 save
if command -v systemctl >/dev/null 2>&1; then
  STARTUP_LINE=$(pm2 startup systemd -u root --hp /root 2>&1 | grep -E 'sudo env|env PATH' | tail -n 1 || true)
  [ -n "$STARTUP_LINE" ] && eval "$STARTUP_LINE" || true
  systemctl enable pm2-root 2>/dev/null || true
fi

# 4) cron：每 3 分钟自愈巡检
CRON_MARK="# xiaobai-tools-watchdog"
CRON_LINE="*/3 * * * * $WATCHDOG >> /var/log/xiaobai-tools-watchdog.log 2>&1 $CRON_MARK"
(crontab -l 2>/dev/null | grep -v "$CRON_MARK"; echo "$CRON_LINE") | crontab -
log "cron watchdog every 3 min (self-heal)"

# 5) cron：每天 04:07 预防性全量修复
HEAL_MARK="# xiaobai-tools-daily-heal"
HEAL_SCRIPT="$BUNDLE/fix-tools-3-6.sh"
if [ ! -f "$HEAL_SCRIPT" ] && [ -f "$SCRIPT_DIR/fix-tools-3-6.sh" ]; then
  cp -f "$SCRIPT_DIR/fix-tools-3-6.sh" "$HEAL_SCRIPT"
  chmod +x "$HEAL_SCRIPT"
fi
HEAL_LINE="7 4 * * * [ -x $HEAL_SCRIPT ] && $HEAL_SCRIPT >> /var/log/xiaobai-tools-daily-heal.log 2>&1 $HEAL_MARK"
(crontab -l 2>/dev/null | grep -v "$HEAL_MARK"; echo "$HEAL_LINE") | crontab -
log "cron daily heal 04:07"

# 6) superllm 临时文件 7 天清理
CLEANUP="$BUNDLE/cleanup-superllm-tmp.sh"
if [ -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" ]; then
  cp -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" "$CLEANUP"
  chmod +x "$CLEANUP"
fi
CLEANUP_MARK="# xiaobai-superllm-tmp-cleanup"
CLEANUP_LINE="17 3 * * * [ -x $CLEANUP ] && $CLEANUP >> /var/log/xiaobai-superllm-cleanup.log 2>&1 $CLEANUP_MARK"
if [ -x "$CLEANUP" ]; then
  (crontab -l 2>/dev/null | grep -v "$CLEANUP_MARK"; echo "$CLEANUP_LINE") | crontab -
fi

# 7) 备份 jar 防误删
JAR="$BUNDLE/services/superllm/yu-ai-agent.jar"
[ -f "$JAR" ] && cp -f "$JAR" "${JAR}.bak" 2>/dev/null || true

pm2 list
crontab -l | grep xiaobai || true
log "ENABLE_TOOLS_ALWAYS_ON_DONE"
log "说明：进程崩溃 pm2 自动拉起；每3分钟自愈(补jar/修启动)；每天4:07预防性检查；服务器重启后 pm2 恢复。"
