#!/bin/bash
set -euo pipefail
curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/install-superllm-tmp-cleanup.sh" \
  -o /tmp/install-superllm-tmp-cleanup.sh
sed -i 's/\r$//' /tmp/install-superllm-tmp-cleanup.sh
bash /tmp/install-superllm-tmp-cleanup.sh
