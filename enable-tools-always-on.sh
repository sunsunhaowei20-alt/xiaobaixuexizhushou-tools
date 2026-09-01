#!/bin/bash
# 一次性执行：让 01摘阅 / 03大模型 / 06小白安装 常驻（开机自启 + 崩溃重启 + 可选巡检）
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[$(date)] ENABLE_TOOLS_ALWAYS_ON start"

# 1) 先确保三个服务当前是起来的
if [ -f "$SCRIPT_DIR/restart-tools-on-server.sh" ]; then
  bash "$SCRIPT_DIR/restart-tools-on-server.sh"
elif [ -f /tmp/restart-tools-on-server.sh ]; then
  bash /tmp/restart-tools-on-server.sh
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/restart-tools-on-server.sh" \
    -o /tmp/restart-tools-on-server.sh
  sed -i 's/\r$//' /tmp/restart-tools-on-server.sh
  bash /tmp/restart-tools-on-server.sh
fi

# 2) pm2 进程列表持久化（重启后恢复）
pm2 save

# 3) 注册 systemd 开机自启（只需成功一次）
if command -v systemctl >/dev/null 2>&1; then
  STARTUP_LINE=$(pm2 startup systemd -u root --hp /root 2>&1 | grep -E 'sudo env|env PATH' | tail -n 1 || true)
  if [ -n "$STARTUP_LINE" ]; then
    echo "running pm2 startup: $STARTUP_LINE"
    eval "$STARTUP_LINE" || true
  fi
  systemctl enable pm2-root 2>/dev/null || true
  systemctl is-enabled pm2-root 2>/dev/null || echo "WARN: pm2-root service not enabled yet"
fi

# 4) 安装轻量巡检脚本（502/进程挂了自动 pm2 restart）
WATCHDOG="/opt/xiaobai-tools/tools-watchdog.sh"
cat > "$WATCHDOG" << 'WATCHDOG_EOF'
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

check() {
  curl -sf -m 5 "$1" >/dev/null 2>&1
}

restarted=0

if ! check "http://127.0.0.1:3000/"; then
  pm2 restart zhaiyue 2>/dev/null || pm2 start /opt/xiaobai-tools/services/zhaiyue/server.js --name zhaiyue --cwd /opt/xiaobai-tools/services/zhaiyue 2>/dev/null || true
  restarted=1
fi

if ! check "http://127.0.0.1:8123/api/swagger-ui.html"; then
  pm2 restart superllm 2>/dev/null || true
  restarted=1
fi

if ! check "http://127.0.0.1:8765/api/health"; then
  pm2 restart xiaobai-api 2>/dev/null || true
  restarted=1
fi

if [ "$restarted" = 1 ]; then
  pm2 save 2>/dev/null || true
  echo "[$(date)] tools-watchdog restarted one or more services"
fi
WATCHDOG_EOF
chmod +x "$WATCHDOG"

# 5) 写入 cron：每 5 分钟巡检一次（重复写入会跳过）
CRON_MARK="# xiaobai-tools-watchdog"
CRON_LINE="*/5 * * * * $WATCHDOG >> /var/log/xiaobai-tools-watchdog.log 2>&1 $CRON_MARK"
if ! crontab -l 2>/dev/null | grep -q "$CRON_MARK"; then
  (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
  echo "cron watchdog installed (every 5 min)"
else
  echo "cron watchdog already present"
fi

# 6) 超级大模型临时文件：超过 7 天自动删除（download/pdf/file）
CLEANUP_SCRIPT="$BUNDLE/cleanup-superllm-tmp.sh"
if [ -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" ]; then
  cp -f "$SCRIPT_DIR/cleanup-superllm-tmp.sh" "$CLEANUP_SCRIPT"
  chmod +x "$CLEANUP_SCRIPT"
elif [ -f "$CLEANUP_SCRIPT" ]; then
  chmod +x "$CLEANUP_SCRIPT"
else
  curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/cleanup-superllm-tmp.sh" \
    -o "$CLEANUP_SCRIPT" 2>/dev/null || true
  chmod +x "$CLEANUP_SCRIPT" 2>/dev/null || true
fi
CLEANUP_MARK="# xiaobai-superllm-tmp-cleanup"
CLEANUP_LINE="17 3 * * * $CLEANUP_SCRIPT >> /var/log/xiaobai-superllm-cleanup.log 2>&1 $CLEANUP_MARK"
if [ -x "$CLEANUP_SCRIPT" ] && ! crontab -l 2>/dev/null | grep -q "$CLEANUP_MARK"; then
  (crontab -l 2>/dev/null; echo "$CLEANUP_LINE") | crontab -
  echo "cron superllm tmp cleanup installed (daily 03:17, 7 days retention)"
elif crontab -l 2>/dev/null | grep -q "$CLEANUP_MARK"; then
  echo "cron superllm tmp cleanup already present"
fi

pm2 list
echo "[$(date)] ENABLE_TOOLS_ALWAYS_ON_DONE"
echo "说明：服务器重启后 pm2 会自动拉起；若进程异常退出 pm2 也会重启；每5分钟额外巡检一次。"
