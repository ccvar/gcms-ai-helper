#!/bin/bash
# 打印站点信息供菜单 App 读取（制表符分隔）。
#   site-info.sh active  → <slug>\t<name>
#   site-info.sh list    → 每行 <slug>\t<name>\t<is_active:0/1>（仅 enabled）
#   site-info.sh full    → 每行 <slug>\t<name>\t<base_url>\t<is_active:0/1>
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$PROJ/sites.json" "${1:-active}" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {"active": "", "sites": []}
mode = sys.argv[2]
a = d.get("active") or ""
sites = d.get("sites", [])
if mode == "list":
    for s in sites:
        if s.get("enabled", True):
            print("\t".join([s["slug"], s.get("name", s["slug"]), "1" if s["slug"] == a else "0"]))
elif mode == "full":
    for s in sites:
        print("\t".join([s["slug"], s.get("name", s["slug"]), s.get("base_url", ""),
                         "1" if s["slug"] == a else "0"]))
else:
    s = next((x for x in sites if x.get("slug") == a), None)
    if s is None:                 # active 为空或失效 → 退回第一个 enabled 站
        s = next((x for x in sites if x.get("enabled", True)), None)
    if s:
        print("\t".join([s["slug"], s.get("name", s["slug"])]))   # 零站点则不输出（菜单走空状态）
PY
