#!/bin/bash
# 移除一个站点：从 sites.json 删除注册（保留数据文件，需彻底删请手动）。
# 各站平级，可全部删空——删到零站点时菜单会显示"还没有站点→添加站点"。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ" || exit 1
SLUG="${1:-}"; [ -z "$SLUG" ] && { echo "用法: remove-site.sh <slug>"; exit 1; }
python3 - "$SLUG" <<'PY'
import json, sys
slug = sys.argv[1]
try:
    d = json.load(open("sites.json"))
except Exception:
    print("ERR: 读不到 sites.json"); sys.exit(1)
sites = d.get("sites", [])
if not any(s.get("slug") == slug for s in sites):
    print("ERR: 没有这个站点：" + slug); sys.exit(1)
d["sites"] = [s for s in sites if s.get("slug") != slug]
if d.get("active") == slug:                 # 删的是当前站 → 切到剩下的第一个；删空则为空
    d["active"] = d["sites"][0]["slug"] if d["sites"] else ""
json.dump(d, open("sites.json", "w"), ensure_ascii=False, indent=2)
print("OK active=" + (d["active"] or "(无)"))
PY
RC=$?
[ "$RC" -ne 0 ] && exit "$RC"
echo "REMOVED $SLUG（数据文件已保留；如需彻底删除请手动删对应目录）"
