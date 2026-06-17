#!/bin/bash
# 从 /languages 接口拉取当前站点启用语种，缓存到该站 config 的 langs_cache（供设置页离线读）。
# 多站：语种/本站语种默认 → SITE_CONFIG；引擎等全局默认 → SITE_GCONFIG（根站为同一文件，自动合并）。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 0
source "$PROJ/automation/site.sh"

TMP="$(mktemp)"
python3 ccvar.py languages 2>/dev/null | sed -n '2,$p' > "$TMP"
python3 - "$SITE_CONFIG" "$SITE_GCONFIG" "$TMP" <<'PY'
import json, sys
scfg, gcfg, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
def load(p):
    try: return json.load(open(p))
    except Exception: return {}
same = (scfg == gcfg)
s = load(scfg)
g = s if same else load(gcfg)

# 本站语种缓存 + 默认
try:
    items = json.load(open(tmp)).get("items", [])
    if items:
        s["langs_cache"] = [{"code": i["code"], "name": i.get("name", i["code"]), "default": bool(i.get("default"))} for i in items]
        if not s.get("write_lang"):
            s["write_lang"] = next((i["code"] for i in items if i.get("default")), items[0]["code"])
except Exception:
    pass
s.setdefault("write_lang", "zh")
s.setdefault("translate_langs", [])
s.setdefault("lang_mode", "translate")
s.pop("bilingual", None)

# 全局引擎默认（只补缺）
g.setdefault("writer_engine", "claude")
g.setdefault("editor_engine", "claude")
g.setdefault("codex_model", "")
g.setdefault("auto_daily_cap", 3)

if same:
    json.dump(s, open(scfg, "w"), ensure_ascii=False, indent=2)   # s 即 g，键齐全
else:
    json.dump(s, open(scfg, "w"), ensure_ascii=False, indent=2)
    json.dump(g, open(gcfg, "w"), ensure_ascii=False, indent=2)
print("langs_cache =", [c["code"] for c in s.get("langs_cache", [])], "| write_lang =", s.get("write_lang"))
PY
rm -f "$TMP"
