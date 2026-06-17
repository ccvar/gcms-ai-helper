#!/bin/bash
# 一次性原子写配置（多站）：全局键→SITE_GCONFIG，每站键→SITE_CONFIG（根站为同一文件，自动合并）。
# 同时更新定时器时间。用法同前（15 个位置参数）。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJ/automation/site.sh"
HH="$1"; MM="$2"; MODEL="$3"; AICMD="$4"; EDITOR="${5:-}"; MODE="${6:-manual}"; VETO="${7:-6}"
CAT="${8:-1}"; WLANG="${9:-zh}"; TLANGS="${10:-}"; COVER="${11:-0}"; LMODE="${12:-translate}"
WENG="${13:-claude}"; EENG="${14:-claude}"; CXMODEL="${15:-}"
python3 - "$SITE_CONFIG" "$SITE_GCONFIG" "$HH" "$MM" "$MODEL" "$AICMD" "$EDITOR" "$MODE" "$VETO" "$CAT" "$WLANG" "$TLANGS" "$COVER" "$LMODE" "$WENG" "$EENG" "$CXMODEL" <<'PY'
import json, sys
a = sys.argv
scfg, gcfg = a[1], a[2]
def load(p):
    try: return json.load(open(p))
    except Exception: return {}
same = (scfg == gcfg)
s = load(scfg)
g = s if same else load(gcfg)
# 全局键（引擎/模型/时间，全站共享）
g["draft_hour"]    = int(a[3])
g["draft_minute"]  = int(a[4])
g["model"]         = a[5]
g["ai_cmd"]        = a[6]
g["editor_model"]  = a[7]
g["writer_engine"] = a[15] if a[15] in ("claude", "codex") else "claude"
g["editor_engine"] = a[16] if a[16] in ("claude", "codex") else "claude"
g["codex_model"]   = a[17]
# 每站键（发布策略/语种）
s["publish_mode"]  = a[8] or "manual"
try: s["veto_hours"] = int(a[9])
except Exception: s["veto_hours"] = 6
s["auto_category"] = a[10] == "1"
s["write_lang"]    = a[11] or "zh"
_codes = [c.strip() for c in a[12].replace("，", ",").split(",") if c.strip()]
s["translate_langs"] = [c for i, c in enumerate(_codes) if c != s["write_lang"] and c not in _codes[:i]]
s["auto_cover"]    = a[13] == "1"
s["lang_mode"]     = a[14] if a[14] in ("translate", "native") else "translate"
s.pop("bilingual", None)
if same:
    json.dump(g, open(gcfg, "w"), ensure_ascii=False, indent=2)   # s 即 g，键齐全
else:
    json.dump(s, open(scfg, "w"), ensure_ascii=False, indent=2)
    json.dump(g, open(gcfg, "w"), ensure_ascii=False, indent=2)
PY
PLIST="$HOME/Library/LaunchAgents/com.ccvar.dailydraft.plist"
if [ -f "$PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $HH" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $MM" "$PLIST" 2>/dev/null || true
  launchctl unload "$PLIST" 2>/dev/null; launchctl load -w "$PLIST" 2>/dev/null
fi
printf "✅ 设置已应用（每天 %02d:%02d）\n" "$HH" "$MM"
