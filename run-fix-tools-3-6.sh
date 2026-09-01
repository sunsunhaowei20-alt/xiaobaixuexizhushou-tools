#!/bin/bash
set -euo pipefail
curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/fix-tools-3-6.sh" -o /tmp/fix-tools-3-6.sh
sed -i 's/\r$//' /tmp/fix-tools-3-6.sh
bash /tmp/fix-tools-3-6.sh
