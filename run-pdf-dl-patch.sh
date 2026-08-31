#!/bin/bash
curl -fsSL -o /tmp/patch-superllm-pdf-dl.zip "https://ghfast.top/https://github.com/sunsunhaowei20-alt/xiaobaixuexizhushou-tools/releases/download/patch-superllm-pdf-dl-20260831/patch-superllm-pdf-dl.zip"
unzip -o /tmp/patch-superllm-pdf-dl.zip -d /tmp/patch-superllm-pdf-dl
bash /tmp/patch-superllm-pdf-dl/deploy.sh
