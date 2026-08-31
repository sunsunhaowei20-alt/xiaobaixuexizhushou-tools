#!/bin/bash
# 删除超级大模型临时文件：download / pdf / file 目录下超过 7 天未修改的文件
set -euo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root

RETENTION_DAYS="${RETENTION_DAYS:-7}"
BUNDLE="${BUNDLE:-/opt/xiaobai-tools}"
LOG_TAG="[$(date '+%Y-%m-%d %H:%M:%S')] superllm-tmp-cleanup"

cleanup_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return 0
  fi
  local removed=0
  while IFS= read -r -d '' f; do
    rm -f "$f"
    removed=$((removed + 1))
  done < <(find "$dir" -maxdepth 1 -type f -mtime "+${RETENTION_DAYS}" -print0 2>/dev/null || true)
  if [ "$removed" -gt 0 ]; then
    echo "$LOG_TAG deleted $removed file(s) in $dir (older than ${RETENTION_DAYS} days)"
  fi
}

for base in /root/tmp "$BUNDLE/services/superllm/tmp"; do
  for sub in download pdf file; do
    cleanup_dir "$base/$sub"
  done
done

echo "$LOG_TAG done"
