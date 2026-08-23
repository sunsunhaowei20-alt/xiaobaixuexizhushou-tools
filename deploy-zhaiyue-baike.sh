#!/bin/bash
# Deploy zhaiyue baike-fix build; keep AI env with /v1
set -euo pipefail

export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BUNDLE=/opt/xiaobai-tools
ZHAIYUE="$BUNDLE/services/zhaiyue"
RUN="$BUNDLE/services/runtime.env"
ZIP_URL="${1:-https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/zhaiyue-baike-20260823/zhaiyue-baike-fix.zip}"

echo "=== $(date) DEPLOY_ZHAIYUE_BAIKE ==="
sed -i 's/\r$//' "$RUN" 2>/dev/null || true
set -a
# shellcheck disable=SC1091
source "$RUN"
set +a

BASE="${AI_BASE_URL%/}"
BASE="${BASE%/v1}"

rm -rf /tmp/zhaiyue-baike /tmp/zhaiyue-baike.zip
mkdir -p /tmp/zhaiyue-baike
curl -fL --connect-timeout 30 --max-time 300 -o /tmp/zhaiyue-baike.zip "$ZIP_URL"
python3 - <<'PY'
import zipfile, os, shutil
root='/tmp/zhaiyue-baike'
with zipfile.ZipFile('/tmp/zhaiyue-baike.zip') as z:
    z.extractall(root)
# fix windows backslash member names if any
for name in os.listdir(root):
    if '\\' in name:
        parts=name.split('\\')
        dst=os.path.join(root, *parts)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(os.path.join(root, name), dst)
print('top', os.listdir(root)[:20])
PY

# backup then replace (keep nothing from old except we rewrite env)
pm2 delete zhaiyue 2>/dev/null || true
mkdir -p "$ZHAIYUE"
# clear old files but keep directory
find "$ZHAIYUE" -mindepth 1 -maxdepth 1 ! -name '.env.local' -exec rm -rf {} +
cp -a /tmp/zhaiyue-baike/. "$ZHAIYUE/"

cat > "$ZHAIYUE/.env.local" << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=${BASE}/v1
AI_MODEL=$AI_MODEL
EOF

PORT=${PORT_ZHAIYUE:-3000} HOSTNAME=127.0.0.1 NODE_ENV=production \
  AI_API_KEY="$AI_API_KEY" \
  AI_BASE_URL="${BASE}/v1" \
  AI_MODEL="$AI_MODEL" \
  pm2 start "$ZHAIYUE/server.js" --name zhaiyue --cwd "$ZHAIYUE" --update-env

pm2 save
sleep 3
pm2 list | grep zhaiyue || true

node - <<'NODE'
const url = 'https://baike.baidu.com/item/%E5%BD%B1%E6%B5%81%E4%B9%8B%E4%B8%BB/6302550';
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

echo "=== $(date) DEPLOY_ZHAIYUE_BAIKE_DONE ==="
