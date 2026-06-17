#!/bin/bash
# 手动发布一篇：维护「正在发布」状态(.publishing) + 发布 + 刷新最近发布缓存。
# 供菜单「确认发布上线」调用，让列表能显示"正在发布上线…"。用法: publish-now.sh <id>
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"
ID="${1:-}"; [ -z "$ID" ] && { echo "用法: publish-now.sh <id> [类型=posts|pages|links]"; exit 1; }
TYPE="${2:-posts}"
case "$TYPE" in links) Q="$SITE_LINKS_QUEUE";; pages) Q="$SITE_PAGES_QUEUE";; *) Q="$SITE_QUEUE";; esac

# 标记正在发布（菜单据此显示）
grep -qxF "$ID" "$SITE_PUBLISHING" 2>/dev/null || echo "$ID" >> "$SITE_PUBLISHING"

OUT="$(bash automation/publish.sh "$ID" "$TYPE" "$Q" 2>&1)"
echo "$OUT"

# 取消标记
if [ -f "$SITE_PUBLISHING" ]; then
  grep -vxF "$ID" "$SITE_PUBLISHING" > "$SITE_PUBLISHING.tmp" 2>/dev/null || true
  mv -f "$SITE_PUBLISHING.tmp" "$SITE_PUBLISHING" 2>/dev/null || true
fi

# 成功则刷新「最近发布」缓存
printf '%s' "$OUT" | grep -q PUBLISH_OK && bash automation/refresh-published.sh >/dev/null 2>&1 || true
