#!/bin/bash
# 内容校准：让 AI 读站内【已发布】文章，校准 topics.md 的「网站定位」，并补几个贴合的新选题。
# 只编辑本地 topics.md，绝不发布。供菜单「校准网站定位…」调用。
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"
[ -f "$PROJ/.claude-auth.env" ] && { set -a; . "$PROJ/.claude-auth.env"; set +a; }
mkdir -p automation/logs
LOG="automation/logs/calibrate-${SITE_SLUG}-$(date +%F).log"

PROMPT="你在 CCVAR 内容运营工作区（当前目录），当前站点：$SITE_NAME。任务：根据站内【已发布】文章，校准本站选题库 $SITE_TOPICS 的三块——网站定位、写作方向、待写队列。步骤：
1. 运行 python3 ccvar.py list posts --status published --limit 100，浏览全部已发布文章的标题与摘要；再挑 3-5 篇代表性的用 python3 ccvar.py get posts <id> 读正文，感受真实调性与深度。
2. 【重写】「## 网站定位（…）」一节的正文（保留该 ## 标题行，只替换其下那段文字）：用一段话说清这个网站真实的定位、目标受众、技术栈侧重、写作调性。贴合已发布内容的实际，不要空泛套话。
3. 【重写】「## 写作方向（…）」一节：根据已发布内容归纳出 4-6 个该站真实的主题方向，每行一个、以 - 开头、用「**加粗小标题**：一句范围说明」的格式（这是以后 AI 自动补题的边界）。替换掉该节里原有的占位或旧内容，保留 ## 标题行。
4. 对照已发布主题与上面的写作方向，找出 3-5 个【还没覆盖、但贴合方向、值得写】的新选题，追加到「## 待写队列」一节末尾（每行一个，以 - 开头）。不要删除已有的待写项，也不要动「## 已写」区。
5. 改完用一句话回报：校准了定位与写作方向、补了哪几个新选题。
红线：绝不创建或发布任何文章；只编辑 $SITE_TOPICS 这一个文件。"

{
  echo "==== $(date '+%F %T') 内容校准开始 ===="
  bash automation/agent.sh writer "$PROMPT"
  echo "==== $(date '+%F %T') 校准结束 exit=$? ===="
} >> "$LOG" 2>&1
echo "DONE"
