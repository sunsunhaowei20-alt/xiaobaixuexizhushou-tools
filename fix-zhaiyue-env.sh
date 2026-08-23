#!/bin/bash
# 修复摘阅 AI_BASE_URL（必须带 /v1）并重启 zhaiyue
set -euo pipefail

BUNDLE=/opt/xiaobai-tools
RUN="$BUNDLE/services/runtime.env"
ZHAIYUE="$BUNDLE/services/zhaiyue"

echo "=== $(date) FIX_ZHAIYUE_ENV ==="
sed -i 's/\r$//' "$RUN" || true
set -a
# shellcheck disable=SC1091
source "$RUN"
set +a

BASE="${AI_BASE_URL%/}"
BASE="${BASE%/v1}"

cat > "$ZHAIYUE/.env.local" << EOF
AI_API_KEY=$AI_API_KEY
AI_BASE_URL=${BASE}/v1
AI_MODEL=$AI_MODEL
EOF

echo "zhaiyue .env.local:"
grep -E '^AI_' "$ZHAIYUE/.env.local" | sed 's/AI_API_KEY=.*/AI_API_KEY=***masked***/'

pm2 delete zhaiyue 2>/dev/null || true
PORT=${PORT_ZHAIYUE:-3000} HOSTNAME=127.0.0.1 NODE_ENV=production \
  AI_API_KEY="$AI_API_KEY" \
  AI_BASE_URL="${BASE}/v1" \
  AI_MODEL="$AI_MODEL" \
  pm2 start server.js --name zhaiyue --cwd "$ZHAIYUE" --update-env
sleep 2
pm2 list | grep zhaiyue || true

# quick smoke test
node -e "
fetch('http://127.0.0.1:3000/api/summarize',{
  method:'POST',
  headers:{'Content-Type':'application/json'},
  body:JSON.stringify({url:'https://www.msn.cn/zh-cn/entertainment/%E5%90%8D%E4%BA%BA/%E7%BD%91%E7%BA%A2-%E5%A4%A7%E5%B8%85-%E7%AA%81%E5%8F%91%E7%96%BE%E7%97%85%E5%8E%BB%E4%B8%96-%E5%B9%B4%E4%BB%8545%E5%B2%81/ar-AA2aK7Bz'})
}).then(async r=>{const j=await r.json(); console.log('status',r.status,'keys',Object.keys(j)); if(j.summary) console.log('summary',j.summary.slice(0,80)); else console.log('error',j.error);}).catch(e=>console.error(e));
" || true

echo "=== $(date) FIX_ZHAIYUE_ENV_DONE ==="
