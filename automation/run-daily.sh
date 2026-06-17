#!/bin/bash
# CCVAR 每日自动撰稿 —— 由 launchd 触发。无人值守撰稿一篇 draft（绝不发布）。
# 路径不写死：可整体拷到别的 Mac 使用。
set -u

# 项目根目录 = 本脚本(automation/)的上一级
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"   # 解析当前站点(CCVAR_SITE/active)：路径 + 配置助手 scfg

# Claude 认证：优先项目内 .claude-auth.env（换电脑也带着走），
# 否则用本机 ~/.claude/setting.json 里现成的登录。
if [ -f "$PROJ/.claude-auth.env" ]; then
  set -a; . "$PROJ/.claude-auth.env"; set +a
elif [ -f "$HOME/.claude/setting.json" ]; then
  _bu="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_BASE_URL",""))' 2>/dev/null)"
  _at="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_AUTH_TOKEN",""))' 2>/dev/null)"
  [ -n "$_bu" ] && export ANTHROPIC_BASE_URL="$_bu"
  [ -n "$_at" ] && export ANTHROPIC_AUTH_TOKEN="$_at"
fi

CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
mkdir -p automation/logs
LOG="automation/logs/daily-${SITE_SLUG}-$(date +%F).log"

# 内容参数：目标字数（空=默认范围）、是否含代码示例
TW="$(scfg target_words '')"
if [ -n "$TW" ] && [ "$TW" -gt 0 ] 2>/dev/null; then LEN="约 $TW 字"; else LEN="1500-2200 字"; fi
case "$(scfg include_code True)" in True|true) CODEREQ="、有代码示例";; *) CODEREQ="";; esac

PROMPT="你现在在 CCVAR 内容运营工作区（当前目录），当前站点：$SITE_NAME。请严格按 automation/daily-draft.md 的步骤，为今天撰稿一篇技术草稿：先读本站选题库 $SITE_TOPICS 顶部的「网站定位」把握调性与受众，并用 python3 ccvar.py list posts 避免撞题；从 $SITE_TOPICS 的「待写队列」选题（队列空了就在「写作方向」范围内自己拟题），写一篇 $LEN、技术向$CODEREQ的 Markdown 文章，用 python3 ccvar.py create posts 创建为 draft（务必 draft，绝不发布），再更新 $SITE_TOPICS 与 $SITE_QUEUE，最后一句话回报草稿 ID 与标题。"

# 自动归类目录（可选，默认开）：让写手按主题选 category_id
AUTO_CAT="$(scfg auto_category True)"
if [ "$AUTO_CAT" = "True" ] || [ "$AUTO_CAT" = "true" ]; then
  PROMPT="$PROMPT 另外，请先运行 python3 ccvar.py categories 查看目录（1=工程 2=SEO 3=设计 4=工具 5=思考），按文章主题选最贴切的一个，create 时带上 --category-id <对应数字>。"
else
  PROMPT="$PROMPT 本次不归类，create 不要带 --category-id。"
fi

# 写作语种（默认 zh）：非中文时覆盖默认中文写作指令
WLANG="$(scfg write_lang zh)"
[ -z "$WLANG" ] && WLANG="zh"
if [ "$WLANG" != "zh" ]; then
  PROMPT="$PROMPT 重要：本次写作语种=$WLANG（zh=中文 en=English 等），请用该语种撰写全文，create 时务必 --lang $WLANG。"
fi

# 写作引擎：默认按 config.writer_engine（claude/codex）走 agent.sh；
# 若设了自定义 ai_cmd 则优先用它（高级逃生口，可接任意 CLI）。
export CCVAR_PROMPT="$PROMPT"
AI_CMD="$(scfg ai_cmd '')"
WENG="$(scfg writer_engine claude)"

# 撰稿前记录待审条数，用于判断是否真新增了草稿
BEFORE=$(grep -cE '^- \[ \]' "$SITE_QUEUE" 2>/dev/null || echo 0)
printf 'RUNNING\t%s\t正在写稿…\n' "$(date +%s)" > "$SITE_STATUS" 2>/dev/null   # 进度状态（菜单可见）

{
  echo "==== $(date '+%F %T') 开始每日撰稿 ===="
  if [ -n "$AI_CMD" ]; then
    echo "[写稿·自定义CLI] ${AI_CMD%% *} …"
    bash -c "$AI_CMD"
  else
    echo "[写稿·$WENG] …"
    bash automation/agent.sh writer "$PROMPT"
  fi
  echo "==== $(date '+%F %T') 写稿结束 exit=$? ===="
} >> "$LOG" 2>&1

# 新草稿 ID = 待审清单最后一条未勾选项（仅当确实新增了一条时）
AFTER=$(grep -cE '^- \[ \]' "$SITE_QUEUE" 2>/dev/null || echo 0)
NEWID=""
[ "$AFTER" -gt "$BEFORE" ] && NEWID=$(grep -E '^- \[ \]' "$SITE_QUEUE" | tail -1 | grep -oE '#[0-9]+' | tr -d '#' | head -1)

# 发布模式：manual / semi / auto（默认 manual）
MODE="$(scfg publish_mode manual)"
[ -z "$MODE" ] && MODE="manual"

if [ -n "$NEWID" ]; then NOTE_MSG="今日草稿已撰稿 #$NEWID，去待审"; else NOTE_MSG="本次没产出新草稿，去运行日志看看"; fi
if [ -n "$NEWID" ] && [ "$MODE" != "manual" ]; then
  echo "==== $(date '+%F %T') 主编审核 #$NEWID（模式 $MODE）====" >> "$LOG"
  printf 'RUNNING\t%s\t#%s 审核中…\n' "$(date +%s)" "$NEWID" > "$SITE_STATUS" 2>/dev/null
  REVIEW_OUT="$(bash automation/review.sh "$NEWID" 2>&1)"
  printf '%s\n' "$REVIEW_OUT" >> "$LOG"
  VLINE="$(printf '%s' "$REVIEW_OUT" | grep -oE 'VERDICT=[A-Z]+\|SCORE=[0-9]+\|NOTE=.*' | tail -1)"
  V="$(printf '%s' "$VLINE" | sed -nE 's/^VERDICT=([A-Z]+).*/\1/p')"
  S="$(printf '%s' "$VLINE" | sed -nE 's/.*SCORE=([0-9]+).*/\1/p')"
  N="$(printf '%s' "$VLINE" | sed -nE 's/.*NOTE=(.*)$/\1/p')"
  # 把主编结论标注到待审清单该条
  python3 - "$SITE_QUEUE" "$NEWID" "${V:-?}" "${S:-?}" "$N" <<'PY'
import sys, re
p, pid, v, s, note = sys.argv[1:6]
tag = {"PASS": "✓建议发布", "HOLD": "⚠需你看", "REJECT": "✗不建议"}.get(v, "主编" + v)
lines = open(p, encoding='utf-8').read().splitlines()
out = []
for l in lines:
    if l.startswith('- [ ]') and re.search(r'#' + re.escape(pid) + r'\b', l) and '〔主编' not in l:
        l = l + f"  〔主编 {tag}·{s} — {note}〕"
    out.append(l)
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
  if [ "$V" = "PASS" ] && [ "$MODE" = "auto" ]; then
    VH="$(scfg veto_hours 6)"; [ -z "$VH" ] && VH=6
    if [ "$VH" -le 0 ] 2>/dev/null; then
      # 否决窗口=0 → 撰稿后立即发布，不进待发布队列
      echo "==== $(date '+%F %T') 否决窗口=0，立即发布 #$NEWID ====" >> "$LOG"
      POUT="$(bash automation/publish-now.sh "$NEWID" 2>&1)"; printf '%s\n' "$POUT" >> "$LOG"
      if printf '%s' "$POUT" | grep -q PUBLISH_OK; then NOTE_MSG="#$NEWID 审核通过(${S})，已自动发布上线"; else NOTE_MSG="#$NEWID 过审但发布失败，看日志"; fi
    else
      AT=$(( $(date +%s) + VH*3600 ))
      printf '%s\t%s\n' "$NEWID" "$AT" >> "$SITE_PENDING"
      NOTE_MSG="#$NEWID 审核通过(${S})，约 ${VH} 小时后自动发布 —— 不想发就去菜单「待发布」取消"
    fi
  else
    case "$V" in
      PASS)   NOTE_MSG="主编建议发布 #$NEWID（${S}分）—— 去待审一键发" ;;
      HOLD)   NOTE_MSG="#$NEWID 需你看一眼：$N" ;;
      REJECT) NOTE_MSG="主编不建议发 #$NEWID：$N" ;;
      *)      NOTE_MSG="#$NEWID 已审，去待审查看" ;;
    esac
  fi
fi

# 可选增强（在 zh 草稿基础上，发布前完成）：自动配图 / 中英双语
if [ -n "$NEWID" ]; then
  AC="$(scfg auto_cover False)"
  if [ "$AC" = "True" ] || [ "$AC" = "true" ]; then
    echo "==== $(date '+%F %T') 自动配图 #$NEWID ====" >> "$LOG"
    bash automation/make-cover.sh "$NEWID" >> "$LOG" 2>&1 || echo "配图失败（跳过）" >> "$LOG"
  fi
  # 译文语种（可选）：对配置里每个目标语种各产一篇版本（翻译 or 独立原创）
  LMODE="$(scfg lang_mode translate)"
  for TL in $(scfg translate_langs); do
    [ "$TL" = "$WLANG" ] && continue
    echo "==== $(date '+%F %T') 生成 $TL 版本（$LMODE）#$NEWID ====" >> "$LOG"
    bash automation/translate.sh "$NEWID" "$TL" "$LMODE" >> "$LOG" 2>&1 || echo "$TL 版本失败（跳过）" >> "$LOG"
  done
fi

# 写完成状态（菜单据此显示"上次撰稿…"）
printf 'DONE\t%s\t%s\n' "$(date +%s)" "$NOTE_MSG" > "$SITE_STATUS" 2>/dev/null

# 完成通知
SAFE_MSG="$(printf '%s' "$NOTE_MSG" | sed "s/\"/'/g")"
/usr/bin/osascript -e "display notification \"$SAFE_MSG\" with title \"CCVAR 撰稿助手\"" 2>/dev/null || true
