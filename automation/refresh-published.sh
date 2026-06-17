#!/bin/bash
# 拉取最近已发布文章，缓存到本地 .recent-published.tsv，供菜单「最近发布」离线、快速读取
# （避免在菜单主线程做网络请求卡 UI）。每行: <id>\t<标题>\t<url>
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 0
source "$PROJ/automation/site.sh"

TMP="$(mktemp)"
python3 ccvar.py list posts --status published --limit 20 2>/dev/null | sed -n '2,$p' > "$TMP"
python3 - "$TMP" "$SITE_RECENT" <<'PY'
import json, sys
src, out = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(src))
    items = data.get("items", data if isinstance(data, list) else [])
except Exception:
    items = []
items.sort(key=lambda p: p.get("published_at") or "", reverse=True)  # 新发布在前
lines = []
for p in items[:8]:
    pid = p.get("id"); title = (p.get("title") or "").replace("\t", " ").strip()
    lang = p.get("lang") or "zh"; slug = p.get("slug") or ""
    url = p.get("url") or f"/{lang}/posts/{slug}"
    if pid and title:
        lines.append(f"{pid}\t{title}\t{url}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + ("\n" if lines else ""))
print(f"cached {len(lines)} published")
PY
rm -f "$TMP"
