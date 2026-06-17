#!/bin/bash
# 生成一篇文章的「某语种版本」：可翻译(translate) 或 独立原创(native)。
# 用 trans_group 与原文绑定，站点即可在各语种间切换。始终只产生 draft，绝不发布。
# 用法：bash automation/translate.sh <原文id> <目标语种代码> [translate|native]
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"
[ -f "$PROJ/.claude-auth.env" ] && { set -a; . "$PROJ/.claude-auth.env"; set +a; }

ID="${1:-}"; LANG_CODE="${2:-}"; LMODE="${3:-translate}"
[ -z "$ID" ] || [ -z "$LANG_CODE" ] && { echo "用法: translate.sh <id> <lang> [translate|native]"; exit 1; }
MODEL="$(python3 -c "import json;print(json.load(open('config.json')).get('editor_model','') or json.load(open('config.json')).get('model','') or 'claude-sonnet-4-6')" 2>/dev/null)"
[ -z "$MODEL" ] && MODEL="claude-sonnet-4-6"

if [ "$LMODE" = "native" ]; then
  INTRO="为 CCVAR 文章 #$ID 产出一个「$LANG_CODE」语种的**原创版本**（语言代码：en=English、ja=日本語、ko=한국어、es=Español 等）。"
  STEP3="3. 面向「$LANG_CODE」语种读者，就同一主题用「$LANG_CODE」**独立原创**一篇技术文章（不是逐句翻译）：核心观点一致，但示例、表达、措辞按该语言习惯本地化、可与原文不同；约 1500-2200 字、有代码示例、不注水。"
else
  INTRO="把 CCVAR 文章 #$ID **翻译**成「$LANG_CODE」语种（语言代码：en=English、ja=日本語、ko=한국어、es=Español 等），创建为该语种草稿。"
  STEP3="3. 把标题、正文(Markdown)、excerpt、meta_desc、keywords 专业地翻成「$LANG_CODE」：技术术语准确、代码块与命令原样保留、不漏段落。"
fi

PROMPT="$(cat <<EOF
$INTRO 步骤：
1. 运行 python3 ccvar.py get posts $ID 读取原文（title / content / excerpt / meta_desc / keywords / slug / category_id / trans_group / lang）。
2. 若原文 lang 已等于 $LANG_CODE，回报"已是该语种，跳过"并结束。
$STEP3
4. 把正文写入 $SITE_DRAFTS/<slug>-$LANG_CODE.md。
5. 用 python3 ccvar.py create posts 创建草稿（务必 draft，绝不加 --allow-publish）：
   --lang $LANG_CODE --title "<$LANG_CODE 标题>" --content-file drafts/<slug>-$LANG_CODE.md --slug "<原slug>-$LANG_CODE"
   --excerpt "<$LANG_CODE 摘要>" --meta-desc "<$LANG_CODE SEO描述>" --keywords "<$LANG_CODE 关键词>"
   归类（重要）：分类是分语种的。若原文有 category_id，先运行 python3 ccvar.py categories --lang $LANG_CODE 列出「$LANG_CODE」语种的分类，找到与原文分类**同 slug**（或同 trans_group）的那一条，用**它的 id** 作为 --category-id；该语种确实没有对应分类时才省略。
   trans_group 用原文的值（原文没有就用原 slug）让各语种版本互相绑定：--trans-group "<原trans_group 或 原slug>"。
6. 记下新草稿 id，追加一行到 $SITE_QUEUE：- [ ] <今天日期> · #<新id> · [$LANG_CODE] <标题> · /$LANG_CODE/posts/<原slug>-$LANG_CODE
7. 一句话回报草稿 id 与语种。
EOF
)"

# 走统一入口：翻译/独立写用「写作引擎」（claude/codex）
bash automation/agent.sh writer "$PROMPT"
