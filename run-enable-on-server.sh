#!/bin/bash
set -eu
curl -fsSL "https://ghfast.top/https://raw.githubusercontent.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/main/enable-tools-always-on.sh" -o /tmp/enable-always-on.sh
sed -i 's/\r$//' /tmp/enable-always-on.sh
bash /tmp/enable-always-on.sh
