#!/bin/bash
# 零手动运维：systemd 定时自愈 + 开机修复 + heal 外网触发 + pm2 持久化
# 用法（服务器只需执行一次）：
#   curl -fsSL https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/install-zero-touch-tools.sh | bash
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
DOMAIN=xiaobaixuexizhushou.cn
NGINX_VHOST="/www/server/panel/vhost/nginx/${DOMAIN}.conf"
LOG=/var/log/xiaobai-zero-touch-install.log
BASE_GH="https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main"

exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) INSTALL_ZERO_TOUCH start ==="

mkdir -p "$BUNDLE"
fetch() {
  local f="$1"
  curl -fsSL "https://ghfast.top/${BASE_GH}/${f}" -o "$BUNDLE/$f" \
    || curl -fsSL "${BASE_GH}/${f}" -o "$BUNDLE/$f"
  chmod +x "$BUNDLE/$f" 2>/dev/null || true
}

for f in fix-tools-3-6.sh tools-watchdog.sh enable-tools-always-on.sh heal-tools-3-6-now.sh; do
  fetch "$f"
done
fetch_py() {
  curl -fsSL "https://ghfast.top/${BASE_GH}/heal-proxy.py" -o "$BUNDLE/heal-proxy.py" \
    || curl -fsSL "${BASE_GH}/heal-proxy.py" -o "$BUNDLE/heal-proxy.py"
}
fetch_py
chmod +x "$BUNDLE/heal-proxy.py" 2>/dev/null || true

# 固定 heal token（仅用于触发修复）
echo "xb-heal-d847ad955f2212645dd3053b773e6418" > "$BUNDLE/heal.token"
chmod 600 "$BUNDLE/heal.token"

# --- 1) 立即修复 ---
bash "$BUNDLE/fix-tools-3-6.sh" || true
bash "$BUNDLE/enable-tools-always-on.sh" || true

# --- 2) systemd：每 2 分钟巡检 ---
cat > /etc/systemd/system/xiaobai-tools-watchdog.service << EOF
[Unit]
Description=Xiaobai tools 3/6 watchdog heal
After=network-online.target

[Service]
Type=oneshot
Environment=HOME=/root
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/bash ${BUNDLE}/tools-watchdog.sh
StandardOutput=append:/var/log/xiaobai-tools-watchdog.log
StandardError=append:/var/log/xiaobai-tools-watchdog.log
EOF

cat > /etc/systemd/system/xiaobai-tools-watchdog.timer << 'EOF'
[Unit]
Description=Run xiaobai tools watchdog every 2 minutes

[Timer]
OnBootSec=90sec
OnUnitActiveSec=2min
AccuracySec=30sec
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- 3) systemd：开机全量修复 ---
cat > /etc/systemd/system/xiaobai-tools-boot.service << EOF
[Unit]
Description=Xiaobai tools boot heal (fix 3/6 on startup)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment=HOME=/root
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/bash ${BUNDLE}/fix-tools-3-6.sh
StandardOutput=append:/var/log/xiaobai-tools-boot.log
StandardError=append:/var/log/xiaobai-tools-boot.log
EOF

# --- 4) systemd：heal-proxy（供 GitHub / 外网触发）---
cat > /etc/systemd/system/xiaobai-heal-proxy.service << EOF
[Unit]
Description=Xiaobai heal HTTP trigger (127.0.0.1:8766)
After=network.target

[Service]
Type=simple
Environment=XIAOBAI_BUNDLE=${BUNDLE}
ExecStart=/usr/bin/python3 ${BUNDLE}/heal-proxy.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xiaobai-tools-watchdog.timer xiaobai-tools-boot.service xiaobai-heal-proxy.service
systemctl start xiaobai-tools-watchdog.timer xiaobai-heal-proxy.service
systemctl start xiaobai-tools-boot.service || true

# --- 5) cron 双保险（systemd 失效时仍生效）---
CRON_D="/etc/cron.d/xiaobai-tools"
cat > "$CRON_D" << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/2 * * * * root ${BUNDLE}/tools-watchdog.sh >> /var/log/xiaobai-tools-watchdog.log 2>&1
@reboot root sleep 120 && ${BUNDLE}/fix-tools-3-6.sh >> /var/log/xiaobai-tools-boot.log 2>&1
EOF
chmod 644 "$CRON_D"

# --- 6) pm2 开机自启 ---
pm2 save 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1; then
  STARTUP_LINE=$(pm2 startup systemd -u root --hp /root 2>&1 | grep -E 'sudo env|env PATH' | tail -n 1 || true)
  [ -n "$STARTUP_LINE" ] && eval "$STARTUP_LINE" || true
  systemctl enable pm2-root 2>/dev/null || true
fi

# --- 7) Nginx：外网 heal 入口（仅 token 可触发）---
if [ -f "$NGINX_VHOST" ]; then
  if ! grep -q 'internal/tools-heal' "$NGINX_VHOST"; then
    python3 - << PY
from pathlib import Path
p = Path("$NGINX_VHOST")
text = p.read_text(encoding="utf-8", errors="ignore")
block = '''
    location = /internal/tools-heal {
        proxy_pass http://127.0.0.1:8766/heal?token=xb-heal-d847ad955f2212645dd3053b773e6418;
        proxy_http_version 1.1;
        allow all;
    }
'''
if "location /api/superllm/" in text and block.strip() not in text:
    text = text.replace("location /api/superllm/", block + "\n    location /api/superllm/", 1)
    p.write_text(text, encoding="utf-8")
    print("nginx heal location added")
else:
    print("nginx skip or already configured")
PY
    /www/server/nginx/sbin/nginx -t 2>/dev/null && /www/server/nginx/sbin/nginx -s reload 2>/dev/null || true
  fi
fi

# --- 8) 标记已安装（防止重复）---
date -Iseconds > "$BUNDLE/.zero-touch-installed"

echo "=== VERIFY ==="
systemctl is-active xiaobai-heal-proxy.service || true
systemctl is-active xiaobai-tools-watchdog.timer || true
curl -s -o /dev/null -w "superllm:%{http_code} " http://127.0.0.1:8123/api/swagger-ui.html || true
curl -s -o /dev/null -w "xiaobai:%{http_code} " http://127.0.0.1:8765/api/health || true
curl -s -o /dev/null -w "heal-proxy:%{http_code}\n" http://127.0.0.1:8766/health || true
pm2 list
echo "=== $(date) INSTALL_ZERO_TOUCH_DONE ==="
