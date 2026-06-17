#!/bin/bash
# 保存 OpenAI API Key 到 .openai.env（codex 可改用按量计费的 API key，替代 ChatGPT 登录）。
# 传空 = 清除（codex 回到 ChatGPT 登录）。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$PROJ/.openai.env"
KEY="$(python3 -c "import sys;print(''.join(sys.argv[1].split()))" "${1:-}" 2>/dev/null)"
if [ -z "$KEY" ]; then
  rm -f "$F"; echo "已清除 OpenAI Key（codex 回到 ChatGPT 登录）"
else
  printf 'OPENAI_API_KEY=%s\n' "$KEY" > "$F"; chmod 600 "$F"; echo "OpenAI Key 已保存（600 + gitignore）"
fi
