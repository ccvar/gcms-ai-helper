#!/bin/bash
# 批量收录链接：读 SITE_LINKS（每行：网址 [| 提示]）。脚本先抓取该页 title+meta 当素材，
# 再让 AI 写【标题 + 详细介绍(content) + 一句话摘要(excerpt)】、可选归类，create links 草稿，
# 可选配图，进链接待审队列；生成成功的网址会从清单"消费"掉（避免重复）。绝不发布。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"

# Claude 认证（与 run-daily 一致）
if [ -f "$PROJ/.claude-auth.env" ]; then set -a; . "$PROJ/.claude-auth.env"; set +a
elif [ -f "$HOME/.claude/setting.json" ]; then
  _bu="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_BASE_URL",""))' 2>/dev/null)"
  _at="$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.claude/setting.json")))["env"].get("ANTHROPIC_AUTH_TOKEN",""))' 2>/dev/null)"
  [ -n "$_bu" ] && export ANTHROPIC_BASE_URL="$_bu"; [ -n "$_at" ] && export ANTHROPIC_AUTH_TOKEN="$_at"
fi

mkdir -p automation/logs "$SITE_DRAFTS"
LOG="automation/logs/links-${SITE_SLUG}-$(date +%F).log"
[ -f "$SITE_LINKS_QUEUE" ] || printf '# 待审链接队列\n\n' > "$SITE_LINKS_QUEUE"
[ -f "$SITE_LINKS" ] || { echo "LINKS_DRAFTED 0"; exit 0; }
WLANG="$(scfg write_lang zh)"; [ -z "$WLANG" ] && WLANG=zh
AUTO_CAT="$(scfg links_auto_category True)"
AUTO_COVER="$(scfg links_auto_cover False)"
LINKS_MODE="$(scfg links_publish_mode manual)"; [ -z "$LINKS_MODE" ] && LINKS_MODE=manual   # manual(无计划)/semi/auto
LINKS_VETO="$(scfg links_veto_hours 1)"; [ -z "$LINKS_VETO" ] && LINKS_VETO=1                # 半自动否决窗口(小时)
LTW="$(scfg links_target_words '')"
if [ -n "$LTW" ] && [ "$LTW" -gt 0 ] 2>/dev/null; then LINTRO="约 $LTW 字"; else LINTRO="2-4 句"; fi   # 详细介绍目标长度
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
TODAY="$(date +%F)"
EXTRACT="$PROJ/automation/.extract-meta.py"
cat > "$EXTRACT" <<'PY'
import sys, re, html
try: t = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
except Exception: t = ''
def grab(p):
    x = re.search(p, t, re.I | re.S)
    return re.sub(r'\s+', ' ', html.unescape(x.group(1))).strip()[:300] if x else ''
title = grab(r'<title[^>]*>(.*?)</title>')
desc  = grab(r'<meta[^>]+name=["\']description["\'][^>]+content=["\']([^"\']*)') or grab(r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']*)')
sys.stdout.write((title or '(无标题)') + '\t' + (desc or '(无摘要)'))
PY

if [ "$AUTO_CAT" = "True" ] || [ "$AUTO_CAT" = "true" ]; then
  CAT_STEP="运行 python3 ccvar.py categories 查看分类，挑最贴切的一个，create 时带 --category-id <对应数字>"
else
  CAT_STEP="本次不归类，create 不要带 --category-id"
fi

printf 'RUNNING\t%s\t正在收录链接…\n' "$(date +%s)" > "$SITE_STATUS" 2>/dev/null
N=0
while IFS= read -r raw || [ -n "$raw" ]; do
  line="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  case "$line" in ''|'#'*) continue;; esac
  URL="$(printf '%s' "${line%%|*}" | sed 's/[[:space:]]*$//')"
  case "$line" in *'|'*) HINT="$(printf '%s' "${line#*|}" | sed 's/^[[:space:]]*//')";; *) HINT="";; esac
  case "$URL" in http://*|https://*) ;; *) echo "跳过非网址: $URL" >> "$LOG"; continue;; esac

  HFILE="$(mktemp)"; MFILE="$(mktemp)"
  curl -sL --max-time 12 -A "$UA" "$URL" 2>/dev/null | head -c 300000 > "$HFILE"
  python3 "$EXTRACT" "$HFILE" > "$MFILE" 2>/dev/null
  IFS=$'\t' read -r PAGE_TITLE PAGE_DESC < "$MFILE"
  rm -f "$HFILE" "$MFILE"
  [ -z "${PAGE_TITLE:-}" ] && PAGE_TITLE="(无标题)"; [ -z "${PAGE_DESC:-}" ] && PAGE_DESC="(无摘要)"

  BEFORE_ID="$(grep -oE '#[0-9]+' "$SITE_LINKS_QUEUE" 2>/dev/null | tail -1)"
  PROMPT="你在 CCVAR 内容运营工作区（当前目录），当前站点：$SITE_NAME。请为本站【链接库】收录一个外部链接。网址：$URL。脚本已抓到该页标题：「$PAGE_TITLE」；该页摘要：「$PAGE_DESC」。${HINT:+用户提示：$HINT。}请：1) 写一个简洁准确的${WLANG}标题；2) 写一段【详细介绍】（${LINTRO}${WLANG}，说清这个链接是什么、有哪些内容、对读者有什么用，别照搬原文）作为正文 content；3) 再写一句话${WLANG}摘要 excerpt；4) $CAT_STEP；5) 用 python3 ccvar.py create links --title \"<标题>\" --link-url \"$URL\" --content \"<详细介绍>\" --excerpt \"<摘要>\" --lang $WLANG --status draft（按上一步决定是否带 --category-id）创建为草稿（务必 status=draft，绝不发布、不要 --allow-publish）。创建成功后把一行『- [ ] $TODAY · #<新链接ID> · <标题> · /links』追加到 $SITE_LINKS_QUEUE（保留已有内容）。最后一句话回报：链接ID 与标题。"
  echo "==== $(date '+%F %T') 收录链接：$URL （抓到标题：$PAGE_TITLE）====" >> "$LOG"
  CCVAR_PROMPT="$PROMPT" bash automation/agent.sh writer "$PROMPT" >> "$LOG" 2>&1

  # 可选配图：拿本次新增的链接 ID 调 make-cover（类型 links）
  AFTER_ID="$(grep -oE '#[0-9]+' "$SITE_LINKS_QUEUE" 2>/dev/null | tail -1)"
  if { [ "$AUTO_COVER" = "True" ] || [ "$AUTO_COVER" = "true" ]; } && [ -n "$AFTER_ID" ] && [ "$AFTER_ID" != "$BEFORE_ID" ]; then
    echo "---- 配图 ${AFTER_ID} ----" >> "$LOG"
    bash automation/make-cover.sh "${AFTER_ID#\#}" links >> "$LOG" 2>&1 || echo "配图失败（跳过）" >> "$LOG"
  fi

  # 按发布模式处理本条：全自动=立即发上线；半自动=进待发布等否决窗口；无计划=留草稿
  if [ -n "$AFTER_ID" ] && [ "$AFTER_ID" != "$BEFORE_ID" ]; then
    NID="${AFTER_ID#\#}"
    case "$LINKS_MODE" in
      auto) echo "---- 全自动发布 $NID ----" >> "$LOG"; bash automation/publish-now.sh "$NID" links >> "$LOG" 2>&1 ;;
      semi) AT=$(( $(date +%s) + LINKS_VETO*3600 )); printf '%s\t%s\t%s\n' "$NID" "$AT" links >> "$SITE_PENDING"; echo "---- 半自动入待发布 $NID（约 ${LINKS_VETO}h 后）----" >> "$LOG" ;;
    esac
  fi
  echo "==== $(date '+%F %T') 该链接结束 ====" >> "$LOG"
  N=$((N+1))
done < "$SITE_LINKS"

rm -f "$EXTRACT"
# 消费：把已处理的网址行注释掉（保留可见、不再重复生成）
if [ "$N" -gt 0 ]; then
  python3 - "$SITE_LINKS" "$TODAY" <<'PY'
import sys
p, today = sys.argv[1], sys.argv[2]
out = []
for l in open(p, encoding='utf-8').read().splitlines():
    s = l.strip()
    out.append(('# 已收录 %s · %s' % (today, l)) if (s and not s.startswith('#')) else l)
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
fi
printf 'DONE\t%s\t已收录 %s 个链接，去「待审链接」\n' "$(date +%s)" "$N" > "$SITE_STATUS" 2>/dev/null
echo "LINKS_DRAFTED $N"
