#!/bin/bash
# 站点解析器（被其它脚本 source）。
# 用法: source automation/site.sh [<slug>]   # 省略则用 sites.json 的 active
# 解析后导出：SITE_SLUG/SITE_NAME/SITE_BASE/SITE_DIR/SITE_KEYFILE/
#            SITE_TOPICS/SITE_QUEUE/SITE_CONFIG/SITE_RECENT/SITE_PUBLISHING/SITE_PENDING/SITE_DRAFTS
# 并导出 CCVAR_BASE_URL + CCVAR_API_KEY（供 ccvar.py 直接用）。
# 所有站点统一存放在 sites/<slug>/（无“根站”特例）。
site_resolve() {
  local PROJ slug info
  PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  slug="${1:-${CCVAR_SITE:-}}"
  info="$(python3 - "$PROJ/sites.json" "$slug" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {"active": "", "sites": []}
slug = sys.argv[2] or d.get("active") or ""
s = next((x for x in d.get("sites", []) if x.get("slug") == slug), None)
if not s:  # 找不到就退回第一个（零站点则为空）
    s = (d.get("sites") or [{}])[0]
    slug = s.get("slug", "")
print("\t".join([
    slug,
    s.get("name", slug),
    s.get("base_url", ""),
]))
PY
)"
  IFS=$'\t' read -r SITE_SLUG SITE_NAME SITE_BASE <<<"$info"

  SITE_DIR="$PROJ/sites/$SITE_SLUG"
  SITE_KEYFILE="$SITE_DIR/site.env"
  SITE_TOPICS="$SITE_DIR/topics.md"; SITE_QUEUE="$SITE_DIR/review-queue.md"; SITE_CONFIG="$SITE_DIR/config.json"
  SITE_RECENT="$SITE_DIR/.recent-published.tsv"; SITE_PUBLISHING="$SITE_DIR/.publishing"
  SITE_PENDING="$SITE_DIR/pending-publish.tsv"; SITE_DRAFTS="$SITE_DIR/drafts"; SITE_STATUS="$SITE_DIR/.runstatus"
  SITE_PAGES="$SITE_DIR/pages.md"; SITE_PAGES_QUEUE="$SITE_DIR/pages-review-queue.md"   # 页面：待起草清单 + 待审队列
  SITE_LINKS="$SITE_DIR/links.md"; SITE_LINKS_QUEUE="$SITE_DIR/links-review-queue.md"   # 链接：待收录网址 + 待审队列

  SITE_GCONFIG="$PROJ/config.json"   # 全局配置（引擎/模型/每日总上限等，全站共享）
  export SITE_SLUG SITE_NAME SITE_BASE SITE_DIR SITE_KEYFILE SITE_GCONFIG \
         SITE_TOPICS SITE_QUEUE SITE_CONFIG SITE_RECENT SITE_PUBLISHING SITE_PENDING SITE_DRAFTS SITE_STATUS \
         SITE_PAGES SITE_PAGES_QUEUE SITE_LINKS SITE_LINKS_QUEUE
  export CCVAR_SITE="$SITE_SLUG"
  export CCVAR_BASE_URL="$SITE_BASE"
  if [ -f "$SITE_KEYFILE" ]; then
    export CCVAR_API_KEY="$(grep '^CCVAR_API_KEY=' "$SITE_KEYFILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"' ' | tr -d ' ')"
  fi
}
# 读配置：先本站 config，再回退全局 config。用法: scfg <key> [默认]
# 布尔→True/False；列表→空格分隔；其它→原值。供脚本统一读配置（根站两文件相同，行为不变）。
scfg() {
  python3 - "${SITE_CONFIG:-}" "${SITE_GCONFIG:-}" "$1" "${2:-}" <<'PY'
import json, sys
sc, gc, key, dflt = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
def load(p):
    try: return json.load(open(p))
    except Exception: return {}
s, g = load(sc), load(gc)
v = s.get(key, g.get(key))
if v is None: v = dflt
if isinstance(v, list): print(' '.join(map(str, v)))
else: print(v)
PY
}

# 注意：只认 CCVAR_SITE 环境变量，不用 "$@"——否则会吃到"调用脚本自己的位置参数"（如 <id>）当成 slug。
site_resolve "${CCVAR_SITE:-}"
