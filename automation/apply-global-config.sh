#!/bin/bash
# 写【全局】设置到 SITE_GCONFIG（撰稿时间 + 引擎/模型 + AI命令），并更新定时器时间。全站共享。
# 用法: apply-global-config.sh <hour> <minute> <model> <ai_cmd> <editor_model> <writer_engine> <editor_engine> <codex_model>
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJ/automation/site.sh"
HH="$1"; MM="$2"
python3 - "$SITE_GCONFIG" "$HH" "$MM" "${3:-}" "${4:-}" "${5:-}" "${6:-claude}" "${7:-claude}" "${8:-}" <<'PY'
import json, sys
a = sys.argv; p = a[1]
try: d = json.load(open(p))
except Exception: d = {}
d["draft_hour"]   = int(a[2])
d["draft_minute"] = int(a[3])
d["model"]        = a[4]
d["ai_cmd"]       = a[5]
d["editor_model"] = a[6]
d["writer_engine"] = a[7] if a[7] in ("claude", "codex") else "claude"
d["editor_engine"] = a[8] if a[8] in ("claude", "codex") else "claude"
d["codex_model"]   = a[9]
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY
PLIST="$HOME/Library/LaunchAgents/com.ccvar.dailydraft.plist"
if [ -f "$PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $HH" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $MM" "$PLIST" 2>/dev/null || true
  launchctl unload "$PLIST" 2>/dev/null; launchctl load -w "$PLIST" 2>/dev/null
fi
printf "✅ 全局设置已保存（每天 %02d:%02d）\n" "$HH" "$MM"
