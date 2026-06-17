#!/bin/bash
# 写【当前活动站】的每站设置到 SITE_CONFIG（发布策略 + 语种 + 增强）。
# 用法: apply-site-config.sh <publish_mode> <veto> <auto_category0/1> <write_lang> <translate_csv> <auto_cover0/1> <lang_mode> <target_words> <include_code0/1>
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJ/automation/site.sh"
python3 - "$SITE_CONFIG" "${1:-manual}" "${2:-6}" "${3:-1}" "${4:-zh}" "${5:-}" "${6:-0}" "${7:-translate}" "${8:-}" "${9:-1}" <<'PY'
import json, sys
a = sys.argv; p = a[1]
try: d = json.load(open(p))
except Exception: d = {}
d["publish_mode"] = a[2] or "manual"
try: d["veto_hours"] = int(a[3])
except Exception: d["veto_hours"] = 6
d["auto_category"] = a[4] == "1"
d["write_lang"] = a[5] or "zh"
_c = [c.strip() for c in a[6].replace("，", ",").split(",") if c.strip()]
d["translate_langs"] = [c for i, c in enumerate(_c) if c != d["write_lang"] and c not in _c[:i]]
d["auto_cover"] = a[7] == "1"
d["lang_mode"] = a[8] if a[8] in ("translate", "native") else "translate"
try: d["target_words"] = int(a[9]) if a[9] else 0
except Exception: d["target_words"] = 0
d["include_code"] = a[10] != "0"
d.pop("bilingual", None)
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY
echo "✅ 本站设置已保存（$SITE_NAME）"
