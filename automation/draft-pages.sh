#!/bin/bash
# 批量起草固定页面：读 SITE_PAGES（每行：标题 | 用途），对每行让 AI 写一稿、create pages 草稿、
# 追加到页面待审队列。由「本站设置·页面」的「起草这些页面」触发。绝不发布。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"

# Claude 认证（与 run-daily 一致：项目内 .claude-auth.env 优先，否则本机登录）
if [ -f "$PROJ/.claude-auth.env" ]; then set -a; . "$PROJ/.claude-auth.env"; set +a
elif [ -f "$HOME/.claude/setting.json" ]; then
  _bu="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_BASE_URL",""))' 2>/dev/null)"
  _at="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_AUTH_TOKEN",""))' 2>/dev/null)"
  [ -n "$_bu" ] && export ANTHROPIC_BASE_URL="$_bu"; [ -n "$_at" ] && export ANTHROPIC_AUTH_TOKEN="$_at"
fi

mkdir -p automation/logs "$SITE_DRAFTS"
LOG="automation/logs/pages-${SITE_SLUG}-$(date +%F).log"
[ -f "$SITE_PAGES_QUEUE" ] || printf '# 待审页面队列\n\n' > "$SITE_PAGES_QUEUE"
[ -f "$SITE_PAGES" ] || { echo "PAGES_DRAFTED 0"; exit 0; }
WLANG="$(scfg write_lang zh)"; [ -z "$WLANG" ] && WLANG=zh
PTW="$(scfg pages_target_words '')"
if [ -n "$PTW" ] && [ "$PTW" -gt 0 ] 2>/dev/null; then PLEN="约 $PTW 字"; else PLEN="500-1200 字"; fi
TODAY="$(date +%F)"

printf 'RUNNING\t%s\t正在起草页面…\n' "$(date +%s)" > "$SITE_STATUS" 2>/dev/null
N=0
while IFS= read -r raw || [ -n "$raw" ]; do
  line="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  case "$line" in ''|'#'*) continue;; esac
  TITLE="$(printf '%s' "${line%%|*}" | sed 's/[[:space:]]*$//')"
  case "$line" in *'|'*) PURPOSE="$(printf '%s' "${line#*|}" | sed 's/^[[:space:]]*//')";; *) PURPOSE="";; esac
  [ -z "$TITLE" ] && continue
  PROMPT="你在 CCVAR 内容运营工作区（当前目录），当前站点：$SITE_NAME。请为本站写【一个页面】（是 page，不是博客文章 post）。标题=「$TITLE」。内容要点：${PURPOSE:-按标题合理展开}。要求：先读 $SITE_TOPICS 顶部「网站定位」把握调性与受众；写一篇 $PLEN、得体、结构清晰的 Markdown 页面正文，语种=$WLANG。把正文先写到一个临时 .md 文件，再用 python3 ccvar.py create pages --title \"$TITLE\" --lang $WLANG --status draft --content-file <该md文件> 创建为草稿（务必 status=draft，绝不发布、绝不加 --allow-publish）。创建成功后，把一行『- [ ] $TODAY · #<新页面ID> · $TITLE · /pages』追加到 $SITE_PAGES_QUEUE（保留已有内容）。最后一句话回报：页面ID 与标题。"
  echo "==== $(date '+%F %T') 起草页面：$TITLE ====" >> "$LOG"
  CCVAR_PROMPT="$PROMPT" bash automation/agent.sh writer "$PROMPT" >> "$LOG" 2>&1
  echo "==== $(date '+%F %T') 该页结束 exit=$? ====" >> "$LOG"
  N=$((N+1))
done < "$SITE_PAGES"

# 消费：把已起草的页面行注释掉（保留可见、不再重复起草）
if [ "$N" -gt 0 ]; then
  python3 - "$SITE_PAGES" "$TODAY" <<'PY'
import sys
p, today = sys.argv[1], sys.argv[2]
out = []
for l in open(p, encoding='utf-8').read().splitlines():
    s = l.strip()
    out.append(('# 已起草 %s · %s' % (today, l)) if (s and not s.startswith('#')) else l)
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
fi
printf 'DONE\t%s\t已起草 %s 个页面，去「待审页面」\n' "$(date +%s)" "$N" > "$SITE_STATUS" 2>/dev/null
echo "PAGES_DRAFTED $N"
