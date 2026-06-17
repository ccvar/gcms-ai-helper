#!/bin/bash
# 全自动发布巡检（多站）：遍历 sites.json 所有启用站点的待发布队列，
# 把"已过否决窗口"的草稿到点发布。每日上限是全局的（跨站合计）。由 launchd 每小时触发。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 0

NOW=$(date +%s); TODAY=$(date +%F)
PUBLOG="$PROJ/automation/logs/published.log"; mkdir -p "$PROJ/automation/logs"
CAP="$(python3 -c "import json;print(json.load(open('config.json')).get('auto_daily_cap',3))" 2>/dev/null)"; [ -z "$CAP" ] && CAP=3
DONE=$(grep -cE "^$TODAY .*自动发布 " "$PUBLOG" 2>/dev/null || echo 0)   # 成功行（失败行是"自动发布失败"，不含空格）

SLUGS="$(python3 -c "import json;print(' '.join(s['slug'] for s in json.load(open('sites.json')).get('sites',[]) if s.get('enabled',True)))" 2>/dev/null)"
[ -z "$SLUGS" ] && SLUGS="ccvar"

for slug in $SLUGS; do
  export CCVAR_SITE="$slug"; source "$PROJ/automation/site.sh"   # 解析该站 SITE_PENDING / SITE_NAME 等
  [ -s "$SITE_PENDING" ] || continue
  TMP="$(mktemp)"
  while IFS=$'\t' read -r ID AT TYPE; do
    [ -z "${ID:-}" ] && continue
    TYPE="${TYPE:-posts}"                       # 兼容老格式(无第三列)=posts
    case "$TYPE" in links) Q="$SITE_LINKS_QUEUE";; pages) Q="$SITE_PAGES_QUEUE";; *) Q="$SITE_QUEUE";; esac
    if [ "${AT:-0}" -le "$NOW" ] && [ "$DONE" -lt "$CAP" ]; then
      OUT="$(bash automation/publish.sh "$ID" "$TYPE" "$Q" 2>&1)"
      if printf '%s' "$OUT" | grep -q PUBLISH_OK; then
        echo "$TODAY $(date '+%T') [$slug] 自动发布 $TYPE #$ID" >> "$PUBLOG"
        DONE=$((DONE+1))
        /usr/bin/osascript -e "display notification \"[$SITE_NAME] 已自动发布 $TYPE #$ID\" with title \"CCVAR 撰稿助手\"" 2>/dev/null || true
      else
        echo "$TODAY $(date '+%T') [$slug] 自动发布失败 $TYPE #$ID: $(printf '%s' "$OUT" | tail -1 | cut -c1-80)" >> "$PUBLOG"
        printf '%s\t%s\t%s\n' "$ID" "$AT" "$TYPE" >> "$TMP"
      fi
    else
      printf '%s\t%s\t%s\n' "$ID" "$AT" "$TYPE" >> "$TMP"
    fi
  done < "$SITE_PENDING"
  mv "$TMP" "$SITE_PENDING"
done
