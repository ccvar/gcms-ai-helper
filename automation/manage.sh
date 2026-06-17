#!/bin/bash
# CCVAR 每日自动撰稿 · 管理工具（路径自适配，可迁移）
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.ccvar.dailydraft.plist"
LABEL="com.ccvar.dailydraft"

case "$1" in
  status)
    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
      echo "✅ 已启用：每天自动撰稿一篇草稿"
    else
      echo "⏸  未启用（用 resume 开启，或先 install.sh）"
    fi
    ;;
  pause)
    launchctl unload "$PLIST" 2>/dev/null && echo "⏸  已暂停。"
    ;;
  resume)
    launchctl load -w "$PLIST" 2>/dev/null && echo "✅ 已恢复。"
    ;;
  run-now)
    echo "▶️  立刻跑一次（约需数分钟）…"
    bash "$PROJ/automation/run-daily.sh"
    echo "完成。看 review-queue.md。"
    ;;
  logs)
    f="$(ls -1t "$PROJ"/automation/logs/daily-*.log 2>/dev/null | head -1)"
    [ -n "$f" ] && { echo "== $f =="; tail -n 30 "$f"; } || echo "还没有运行日志。"
    ;;
  set-time)
    HH="$2"; MM="$3"
    [ -z "$HH" ] || [ -z "$MM" ] && { echo "用法: set-time HH MM"; exit 1; }
    # 写入 config.json
    python3 - "$PROJ/config.json" "$HH" "$MM" <<'PY'
import json,sys
p,h,m=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
try: d=json.load(open(p))
except Exception: d={}
d["draft_hour"]=h; d["draft_minute"]=m
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
PY
    # 更新定时器
    if [ -f "$PLIST" ]; then
      /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $HH" "$PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Hour integer $HH" "$PLIST"
      /usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $MM" "$PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Minute integer $MM" "$PLIST"
      launchctl unload "$PLIST" 2>/dev/null; launchctl load -w "$PLIST"
      printf "✅ 已设为每天 %02d:%02d 撰稿。\n" "$HH" "$MM"
    else
      echo "定时器尚未安装，请先运行 automation/install.sh"
    fi
    ;;
  set-cli)
    CMD="$2"
    python3 - "$PROJ/config.json" "$CMD" <<'PY'
import json,sys
p,cmd=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
d["ai_cmd"]=cmd
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
PY
    [ -z "$CMD" ] && echo "✅ 已恢复默认 AI（Claude）" || echo "✅ AI 命令已更新"
    ;;
  set-model)
    M="$2"
    python3 - "$PROJ/config.json" "$M" <<'PY'
import json,sys
p,m=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
d["model"]=m
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
PY
    [ -z "$M" ] && echo "✅ 模型恢复默认（跟随全局）" || echo "✅ 模型已设为 $M"
    ;;
  set-editor)
    python3 - "$PROJ/config.json" "$2" <<'PY'
import json,sys
p,em=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
d["editor_model"]=em
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
PY
    [ -z "$2" ] && echo "✅ 审核模型：跟随写作模型" || echo "✅ 审核模型设为 $2"
    ;;
  set-mode)
    M="${2:-manual}"
    python3 - "$PROJ/config.json" "$M" <<'PY'
import json,sys
p,mode=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
d["publish_mode"]=mode
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
PY
    echo "✅ 发布模式设为 $M"
    ;;
  set-category|set-cover)
    KEY="auto_category"; [ "$1" = "set-cover" ] && KEY="auto_cover"
    python3 - "$PROJ/config.json" "$KEY" "${2:-on}" <<'PY'
import json,sys
p,key,v=sys.argv[1],sys.argv[2],sys.argv[3].strip().lower()
on = v in ("on","1","true","yes","y","开")
try: d=json.load(open(p))
except Exception: d={}
d[key]=on
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print(f"✅ {key} = {'开' if on else '关'}")
PY
    ;;
  set-write-lang)
    python3 - "$PROJ/config.json" "${2:-zh}" <<'PY'
import json,sys
p,code=sys.argv[1],sys.argv[2].strip()
try: d=json.load(open(p))
except Exception: d={}
d["write_lang"]=code or "zh"
d["translate_langs"]=[c for c in d.get("translate_langs",[]) if c!=d["write_lang"]]
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print(f"✅ 写作语种 = {d['write_lang']}")
PY
    ;;
  set-langs)
    python3 - "$PROJ/config.json" "${2:-}" <<'PY'
import json,sys
p,csv=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
codes=[c.strip() for c in csv.replace("，",",").split(",") if c.strip()]
wl=d.get("write_lang","zh")
d["translate_langs"]=[c for c in dict.fromkeys(codes) if c!=wl]
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print("✅ 译文语种 =", d["translate_langs"] or "（无，关闭）")
PY
    ;;
  set-lang-mode)
    M="${2:-translate}"; [ "$M" != "native" ] && M="translate"
    python3 - "$PROJ/config.json" "$M" <<'PY'
import json,sys
p,m=sys.argv[1],sys.argv[2]
try: d=json.load(open(p))
except Exception: d={}
d["lang_mode"]=m
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print("✅ 译文方式 =", "各语种独立撰写" if m=="native" else "翻译生成")
PY
    ;;
  set-writer-engine|set-editor-engine)
    KEY="writer_engine"; [ "$1" = "set-editor-engine" ] && KEY="editor_engine"
    E="${2:-claude}"; [ "$E" != "codex" ] && E="claude"
    python3 - "$PROJ/config.json" "$KEY" "$E" <<'PY'
import json,sys
p,key,e=sys.argv[1],sys.argv[2],sys.argv[3]
try: d=json.load(open(p))
except Exception: d={}
d[key]=e
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print(f"✅ {key} = {e}")
PY
    ;;
  set-codex-model)
    python3 - "$PROJ/config.json" "${2:-}" <<'PY'
import json,sys
p,m=sys.argv[1],sys.argv[2].strip()
try: d=json.load(open(p))
except Exception: d={}
d["codex_model"]=m
json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)
print("✅ codex_model =", m or "(codex 默认)")
PY
    ;;
  *)
    echo "用法: bash automation/manage.sh {status|pause|resume|run-now|logs|set-time HH MM|set-cli CMD|set-model M|set-editor M|set-mode manual/semi/auto|set-category on/off|set-cover on/off|set-write-lang CODE|set-langs en,ja|set-lang-mode translate/native|set-writer-engine claude/codex|set-editor-engine claude/codex|set-codex-model M}"
    ;;
esac
