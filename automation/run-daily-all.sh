#!/bin/bash
# 多站每日撰稿：遍历 sites.json 所有启用站点，依次撰稿（错峰，避免额度突刺）。
# 由 launchd 定时器调用。单站时等价于跑一次 run-daily.sh。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1

SLUGS="$(python3 -c "import json;print(' '.join(s['slug'] for s in json.load(open('sites.json')).get('sites',[]) if s.get('enabled',True)))" 2>/dev/null)"
[ -z "$SLUGS" ] && SLUGS="ccvar"

first=1
for slug in $SLUGS; do
  [ "$first" = 1 ] || sleep 120        # 站间错峰 2 分钟
  first=0
  CCVAR_SITE="$slug" bash automation/run-daily.sh
done
