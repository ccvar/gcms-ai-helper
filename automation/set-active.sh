#!/bin/bash
# 切换当前活动站点（写 sites.json 的 active）。供菜单「切换站点」调用。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ" || exit 1
SLUG="${1:-}"; [ -z "$SLUG" ] && { echo "用法: set-active.sh <slug>"; exit 1; }
python3 - "$SLUG" <<'PY'
import json, sys
slug = sys.argv[1]
d = json.load(open("sites.json"))
if any(s.get("slug") == slug for s in d.get("sites", [])):
    d["active"] = slug
    json.dump(d, open("sites.json", "w"), ensure_ascii=False, indent=2)
    print("✅ 活动站 =", slug)
else:
    print("⚠️ 没有这个站:", slug)
PY
