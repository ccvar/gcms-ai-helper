#!/bin/bash
# 从自动发布队列移除一篇（= 否决/取消自动发布）。供菜单调用。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJ/automation/site.sh"
Q="$SITE_PENDING"
ID="$1"; [ -z "$ID" ] && { echo "用法: unqueue-publish.sh <ID>"; exit 1; }
if [ -f "$Q" ]; then
  awk -F'\t' -v id="$ID" '$1!=id' "$Q" > "$Q.tmp" && mv "$Q.tmp" "$Q"
fi
echo "已取消 #$ID 的自动发布"
