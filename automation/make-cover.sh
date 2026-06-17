#!/bin/bash
# 自动配图（可选）：给一篇文章生成品牌封面图 → 上传 /media → 写回 cover_image。
# 用法：bash automation/make-cover.sh <id>
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"

ID="${1:-}"; [ -z "$ID" ] && { echo "用法: make-cover.sh <id> [类型=posts|pages|links]"; exit 1; }
TYPE="${2:-posts}"

# 取标题（ccvar.py 首行是 HTTP 状态码，从第 2 行起才是 JSON）
TITLE="$(python3 ccvar.py get "$TYPE" "$ID" 2>/dev/null | sed -n '2,$p' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['item'].get('title',''))" 2>/dev/null)"
[ -z "$TITLE" ] && { echo "取标题失败 #$ID"; exit 1; }

mkdir -p "$SITE_DRAFTS"
PNG="$SITE_DRAFTS/cover-$ID.png"
# 首次用到时现编译渲染器
[ -x build/render-cover ] || swiftc build/render-cover.swift -o build/render-cover 2>/dev/null
[ -x build/render-cover ] || { echo "渲染器不可用（需 swiftc）"; exit 1; }
build/render-cover "$TITLE" "$PNG" >/dev/null || { echo "渲染封面失败 #$ID"; exit 1; }

# 上传 → 取 url
URL="$(python3 ccvar.py media "$PNG" 2>/dev/null | sed -n '2,$p' \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('url',''))" 2>/dev/null)"
[ -z "$URL" ] && { echo "上传失败/未取到 URL #$ID"; exit 1; }

python3 ccvar.py update "$TYPE" "$ID" --cover-image "$URL" >/dev/null 2>&1 \
  && echo "封面已设置 #$ID -> $URL" || { echo "写回 cover_image 失败 #$ID"; exit 1; }
