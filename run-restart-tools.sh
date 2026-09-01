#!/bin/bash
set -euo pipefail
curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/restart-tools-on-server.sh" \
  -o /tmp/restart-tools-on-server.sh
sed -i 's/\r$//' /tmp/restart-tools-on-server.sh
bash /tmp/restart-tools-on-server.sh
