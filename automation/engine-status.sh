#!/bin/bash
# 检测两个撰稿引擎的状态，供「全局设置」面板点灯 + 决定按钮（安装/登录/切换）。
# 输出两行（制表符分隔）：<engine>\t<state>\t<一句话说明>
#   state: missing=未安装命令  noauth=已装未登录/未配置  ok=就绪
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# ---------- Claude ----------
if ! command -v claude >/dev/null 2>&1; then
  printf 'claude\tmissing\t未安装 claude 命令\n'
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || grep -q '^CLAUDE_CODE_OAUTH_TOKEN=.\+' "$PROJ/.claude-auth.env" 2>/dev/null; then
  printf 'claude\tok\t已配置访问令牌\n'
elif [ -f "$HOME/.claude/setting.json" ] && python3 -c 'import json,os,sys; d=json.load(open(os.path.expanduser("~/.claude/setting.json"))); sys.exit(0 if d.get("env",{}).get("ANTHROPIC_AUTH_TOKEN") else 1)' 2>/dev/null; then
  printf 'claude\tok\t已用本机 Claude 登录\n'
elif [ -f "$HOME/.claude.json" ] && python3 -c 'import json,os,sys; d=json.load(open(os.path.expanduser("~/.claude.json"))); sys.exit(0 if (d.get("oauthAccount") or d.get("primaryApiKey")) else 1)' 2>/dev/null; then
  printf 'claude\tok\t已用本机 Claude 登录\n'
else
  printf 'claude\tnoauth\t已安装、未登录\n'
fi

# ---------- GPT (codex) ----------
if ! command -v codex >/dev/null 2>&1; then
  printf 'gpt\tmissing\t未安装 codex 命令\n'
elif [ -n "${OPENAI_API_KEY:-}" ] || grep -q '^OPENAI_API_KEY=.\+' "$PROJ/.openai.env" 2>/dev/null; then
  printf 'gpt\tok\t已配置 OpenAI Key（按量计费）\n'
elif codex login status 2>&1 | grep -qi 'logged in'; then
  printf 'gpt\tok\tChatGPT 已登录（免费额度）\n'
else
  printf 'gpt\tnoauth\t已安装、未登录\n'
fi
