#!/bin/bash
# 部署摘阅 MSN/一点资讯 vi- 视频链接修复
set -euo pipefail
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BUNDLE=/opt/xiaobai-tools
ZHAIYUE="$BUNDLE/services/zhaiyue"
RUN="$BUNDLE/services/runtime.env"
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/zhaiyue-msn-yidian-20260901/zhaiyue-msn-yidian.zip}"

echo "=== $(date) DEPLOY_ZHAIYUE_MSN_YIDIAN ==="
sed -i 's/\r$//' "$RUN" 2>/dev/null || true
set -a
# shellcheck disable=SC1091
source "$RUN"
set +a
BASE="${AI_BASE_URL%/}"; BASE="${BASE%/v1}"

rm -rf /tmp/zhaiyue-msn-yidian /tmp/zhaiyue-msn-yidian.zip
mkdir -p /tmp/zhaiyue-msn-yidian
curl -fL --connect-timeout 30 --max-time 300 -o /tmp/zhaiyue-msn-yidian.zip "$ZIP_URL"
python3 - <<'PY'
import zipfile, os, shutil
root='/tmp/zhaiyue-msn-yidian'
with zipfile.ZipFile('/tmp/zhaiyue-msn-yidian.zip') as z:
    z.extractall(root)
for name in os.listdir(root):
    if '\\' in name:
        parts=name.split('\\')
        dst=os.path.join(root, *parts)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(os.path.join(root, name), dst)
PY

pm2 delete zhaiyue 2>/dev/null || true
mkdir -p "$ZHAIYUE"
find "$ZHAIYUE" -mindepth 1 -maxdepth 1 ! -name '.env.local' -exec rm -rf {} +
cp -a /tmp/zhaiyue-msn-yidian/. "$ZHAIYUE/"

cat > "$ZHAIYUE/.env.local" << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=${BASE}/v1
AI_MODEL=$AI_MODEL
EOF

PORT=${PORT_ZHAIYUE:-3000} HOSTNAME=127.0.0.1 NODE_ENV=production \
  AI_API_KEY="$AI_API_KEY" \
  AI_BASE_URL="${BASE}/v1" \
  AI_MODEL="$AI_MODEL" \
  pm2 start "$ZHAIYUE/server.js" --name zhaiyue --cwd "$ZHAIYUE" --update-env --max-memory-restart 400M

pm2 save
sleep 3
node - <<'NODE'
const url = 'https://msn.yidianzixun.com/zh-cn/video/webcontent/web-content/vi-AA26jUxx?vid=vi-AA26jUxx&locale=zh-CN';
fetch('http://127.0.0.1:3000/api/summarize', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ url }),
}).then(async (r) => {
  const j = await r.json();
  console.log('status', r.status);
  if (j.summary) console.log('OK', (j.title||'').slice(0,40), j.summary.slice(0,120));
  else console.log('ERR', j.error);
}).catch((e) => console.error(e));
NODE
echo "=== $(date) DEPLOY_ZHAIYUE_MSN_YIDIAN_DONE ==="
