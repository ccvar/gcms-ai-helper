#!/bin/bash
# 发布一篇草稿：把指定 ID 的文章设为 published。
# 需要 CCVAR API Key 含 publish 权限，否则服务器会拒绝。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"
ID="$1"
[ -z "$ID" ] && { echo "用法: publish.sh <草稿ID> [类型=posts|pages|links] [队列文件]"; exit 1; }
TYPE="${2:-posts}"                 # 资源类型，默认文章
QUEUE_FILE="${3:-$SITE_QUEUE}"     # 勾掉用的队列，默认文章待审队列

OUT="$(python3 ccvar.py update "$TYPE" "$ID" --status published --allow-publish 2>&1)"
echo "$OUT"

if printf '%s' "$OUT" | grep -q '"status": *"published"'; then
  # 在对应队列把该条勾掉
  python3 - "$QUEUE_FILE" "$ID" <<'PY'
import sys, re
p, pid = sys.argv[1], sys.argv[2]
try: lines = open(p, encoding='utf-8').read().splitlines()
except FileNotFoundError: lines = []
out = []
for l in lines:
    if re.search(r'#' + re.escape(pid) + r'\b', l):
        l = l.replace('- [ ]', '- [x]', 1)
    out.append(l)
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
  echo "PUBLISH_OK"
else
  echo "PUBLISH_FAIL"
fi
