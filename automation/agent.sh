#!/bin/bash
# 统一的 agent 入口：按"角色"从 config 读引擎(claude/codex)+模型，拼上厂商专属护栏，
# 调对应 CLI 执行提示词。写稿/审核/翻译三处都走它，引擎可自由组合（如 GPT 写 + Claude 审）。
# 用法: agent.sh <writer|editor> "<提示词>"
# 调试: AGENT_DRYRUN=1 agent.sh writer "x"   # 只打印将执行的命令，不真跑模型
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
ROLE="${1:-writer}"; PROMPT="${2:-}"
[ -z "$PROMPT" ] && { echo "agent.sh: 空提示词" >&2; exit 1; }

# 该角色用哪个引擎、哪个模型（claude 用 model/editor_model；codex 用 codex_model）
read -r ENGINE MODEL < <(python3 - "$PROJ/config.json" "$ROLE" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
role = sys.argv[2]
if role == "editor":
    eng = d.get("editor_engine", "claude") or "claude"
    model = d.get("editor_model", "") if eng == "claude" else d.get("codex_model", "")
else:
    eng = d.get("writer_engine", "claude") or "claude"
    model = d.get("model", "") if eng == "claude" else d.get("codex_model", "")
print(eng, model or "-")
PY
)
[ "$MODEL" = "-" ] && MODEL=""

# 追加厂商专属护栏/风格段
GFILE="$PROJ/automation/prompts/$ENGINE.md"
[ -f "$GFILE" ] && PROMPT="$PROMPT

$(cat "$GFILE")"

if [ "$ENGINE" = "codex" ]; then
  # 若设置了 OpenAI API Key 则注入（codex 优先用它）；没有就用本机 ChatGPT 登录
  [ -f "$PROJ/.openai.env" ] && { set -a; . "$PROJ/.openai.env"; set +a; }
  # GPT(codex)：无人值守需全权（联网+无审批）；靠 codex 护栏(prompts/codex.md)约束行为
  BIN="codex"
  ARGS=( exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -C "$PROJ" -c shell_environment_policy.inherit=all )
  [ -n "$MODEL" ] && ARGS+=( -m "$MODEL" )
  ARGS+=( "$PROMPT" )
else
  # Claude：用 --allowedTools 从结构上限制可用工具
  BIN="claude"
  ARGS=( -p "$PROMPT" --permission-mode default --allowedTools "Bash(python3 ccvar.py:*)" "Read" "Write" "Edit" "Bash(ls:*)" "Bash(grep:*)" "Bash(wc:*)" "Bash(find:*)" --output-format text )
  [ -n "$MODEL" ] && ARGS=( --model "$MODEL" "${ARGS[@]}" )
fi

if [ "${AGENT_DRYRUN:-0}" = "1" ]; then
  printf '[dryrun] role=%s engine=%s model=%s bin=%s\n' "$ROLE" "$ENGINE" "${MODEL:-<default>}" "$BIN"
  exit 0
fi
# codex 认证预检：没填 OpenAI Key 且 codex 未登录时，明确报错而不是闷头失败
if [ "$ENGINE" = "codex" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  if ! codex login status 2>&1 | grep -qi 'logged in'; then
    echo "⚠️ GPT(codex) 未认证：请在终端运行一次 codex login（ChatGPT 账号），或在「设置」填 OpenAI Key。本次跳过。" >&2
    exit 3
  fi
fi
exec "$BIN" "${ARGS[@]}"
