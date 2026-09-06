#!/bin/bash
# 修复 Nginx heal 入口 + 立即修复 3/6 + 确认 systemd 定时器
set -u
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BUNDLE=/opt/xiaobai-tools
DOMAIN=xiaobaixuexizhushou.cn
VHOST="/www/server/panel/vhost/nginx/${DOMAIN}.conf"

echo "=== $(date) FIX_NGINX_HEAL_AND_TOOLS ==="

# 1) Nginx heal 反代（GitHub 外网巡检依赖此入口）
if [ -f "$VHOST" ]; then
  python3 - << PY
from pathlib import Path
p = Path("$VHOST")
t = p.read_text(encoding="utf-8", errors="ignore")
block = """
    location = /internal/tools-heal {
        proxy_pass http://127.0.0.1:8766/heal?token=xb-heal-d847ad955f2212645dd3053b773e6418;
        proxy_http_version 1.1;
        allow all;
    }
"""
if "/internal/tools-heal" not in t:
    if "location /api/superllm/" in t:
        t = t.replace("location /api/superllm/", block + "    location /api/superllm/", 1)
    elif "location /api/xiaobai/" in t:
        t = t.replace("location /api/xiaobai/", block + "    location /api/xiaobai/", 1)
    else:
        t = t.replace("server {", "server {\n" + block, 1)
    p.write_text(t, encoding="utf-8")
    print("nginx heal location added")
else:
    print("nginx heal already present")
PY
  /www/server/nginx/sbin/nginx -t && /www/server/nginx/sbin/nginx -s reload
fi

# 2) 确保 heal-proxy 在跑
systemctl enable xiaobai-heal-proxy.service 2>/dev/null || true
systemctl restart xiaobai-heal-proxy.service 2>/dev/null || true

# 3) 确保 systemd 定时器在跑
systemctl enable xiaobai-tools-watchdog.timer 2>/dev/null || true
systemctl start xiaobai-tools-watchdog.timer 2>/dev/null || true

# 4) 拉最新脚本并全量修复
BASE="https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main"
for f in fix-tools-3-6.sh tools-watchdog.sh install-zero-touch-tools.sh heal-proxy.py; do
  curl -fsSL "$BASE/$f" -o "$BUNDLE/$f" 2>/dev/null || curl -fsSL "https://ghfast.top/$BASE/$f" -o "$BUNDLE/$f" || true
  chmod +x "$BUNDLE/$f" 2>/dev/null || true
done
cp -f "$BUNDLE/heal-proxy.py" "$BUNDLE/heal-proxy.py"
systemctl restart xiaobai-heal-proxy.service 2>/dev/null || true
bash "$BUNDLE/fix-tools-3-6.sh" || true

# 5) 验证
echo "heal-proxy local: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8766/health 2>/dev/null || echo 000)"
echo "heal nginx: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: $DOMAIN' http://127.0.0.1/internal/tools-heal 2>/dev/null || echo 000)"
echo "superllm: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8123/api/swagger-ui.html 2>/dev/null || echo 000)"
echo "xiaobai: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765/api/health 2>/dev/null || echo 000)"
systemctl is-active xiaobai-tools-watchdog.timer 2>/dev/null || echo "timer inactive"
pm2 list
echo "=== $(date) FIX_NGINX_HEAL_AND_TOOLS_DONE ==="
