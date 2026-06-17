#!/bin/bash
# 草稿预览：优先用接口的在线预览(frontend_preview_url，走真站主题)，失败回退本地 HTML。
# 打印要打开的"地址"（http 在线链接 或 本地文件路径），供菜单「预览」用 open 打开。
# 用法: preview-draft.sh <id>
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"
ID="${1:-}"; [ -z "$ID" ] && { echo "用法: preview-draft.sh <id> [类型=posts|pages|links]"; exit 1; }
TYPE="${2:-posts}"
mkdir -p "$SITE_DRAFTS"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
PUB="$(printf '%s' "${SITE_BASE:-}" | sed -E 's#(https?://[^/]+).*#\1#')"   # 本站公开域名
TMP="$(mktemp)"
python3 ccvar.py preview "$TYPE" "$ID" 2>/dev/null | sed -n '2,$p' > "$TMP"

# 1) 在线优先：取 frontend_preview_url，浏览器模拟静默试开，HTTP 200 才用它
FPU="$(python3 -c "import json,sys
try:
    print(json.load(open(sys.argv[1]))['preview'].get('frontend_preview_url','') or '')
except Exception:
    print('')" "$TMP" 2>/dev/null)"
if [ -n "$FPU" ]; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -A "$UA" "$FPU" 2>/dev/null)"
  if [ "$CODE" = "200" ]; then rm -f "$TMP"; printf '%s\n' "$FPU"; exit 0; fi
fi

# 2) 回退本地 HTML（用接口的 content_html 本地排版）
OUT="$SITE_DRAFTS/preview-$ID.html"
python3 - "$OUT" "$TMP" "${PUB:-https://ccvar.com}" <<'PY'
import sys, json, html, re
out, src, pub = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    p = json.load(open(src)).get("preview", {})
except Exception:
    raise SystemExit(1)
item = p.get("item", {})
title = html.escape(item.get("title", "预览"))
body = p.get("content_html") or "<p>（无预览内容）</p>"
body = re.sub(r'(src|href)="/', r'\1="' + pub + '/', body)   # 相对链接补全为本站绝对地址
doc = f"""<!doctype html><html lang="{item.get('lang','zh')}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>预览 · {title}</title>
<style>
 body{{max-width:760px;margin:36px auto;padding:0 20px;font:16px/1.7 -apple-system,system-ui,'PingFang SC',sans-serif;color:#1a1a1a}}
 .banner{{background:#9a3b2f;color:#fff;padding:8px 14px;border-radius:8px;font-size:13px;margin-bottom:24px}}
 h1{{font-size:30px;line-height:1.3}} h2{{margin-top:1.6em}} pre{{background:#f5f5f5;padding:14px;border-radius:8px;overflow:auto}}
 code{{background:#f0f0f0;padding:2px 5px;border-radius:4px}} pre code{{background:none;padding:0}}
 img{{max-width:100%}} a{{color:#9a3b2f}} blockquote{{border-left:3px solid #ddd;margin:0;padding-left:16px;color:#555}}
</style></head><body>
<div class="banner">草稿本地预览（未发布·在线预览暂不可用时的兜底）· #{item.get('id','')} · 语种 {item.get('lang','')}</div>
<h1>{title}</h1>
{body}
</body></html>"""
open(out, "w", encoding="utf-8").write(doc)
print(out)
PY
rm -f "$TMP"
