#!/bin/bash
# 主编引擎：让审核模型按 review-draft.md 审核 + 润色指定草稿，并输出结论。
# 用法: review.sh <草稿ID> [模型]
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
cd "$PROJ" || exit 1
source "$PROJ/automation/site.sh"   # 多站：导出 CCVAR_SITE 供 agent/ccvar.py 指向正确站点
ID="$1"; MODEL="${2:-}"
[ -z "$ID" ] && { echo "用法: review.sh <草稿ID> [模型]"; exit 1; }

# 认证（同每日撰稿）
if [ -f "$PROJ/.claude-auth.env" ]; then
  set -a; . "$PROJ/.claude-auth.env"; set +a
fi

PROMPT="你是 CCVAR 简记的主编。请严格按 automation/review-draft.md 的步骤，审核并润色草稿 #$ID：读取 → 按清单审核 → 用 python3 ccvar.py update 把改进写回（保持 draft，绝不发布）→ 回复最后一行严格输出 VERDICT=...|SCORE=...|NOTE=... 的结论。"

# 走统一入口 agent.sh：按 config.editor_engine 选 Claude 或 GPT 当主编（模型也由它定）
OUT="$(bash automation/agent.sh editor "$PROMPT" < /dev/null 2>&1)"
echo "$OUT"
echo "----"
# 提取结论行（供上层流程解析）
echo "$OUT" | grep -oE 'VERDICT=[A-Z]+\|SCORE=[0-9]+\|NOTE=.*' | tail -1
