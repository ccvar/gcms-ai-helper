#!/bin/bash
# 打开「终端」引导用户完成 Claude / GPT(codex) 的账号登录/授权（浏览器 OAuth）。
# 用 .command 临时脚本 + open，避免请求控制 Terminal 的自动化权限。
# 用法: engine-login.sh <claude|gpt>
set -u
WHICH="${1:-}"
TMP="$(mktemp -t cc-login).command"
{
  echo '#!/bin/bash'
  echo 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"'
  if [ "$WHICH" = "claude" ]; then
    echo 'echo "============ 登录 Claude 并生成访问令牌 ============"'
    echo 'echo "浏览器会打开授权页；完成后这里会打印一串令牌。"; echo'
    echo 'claude setup-token || echo "（若失败：claude setup-token 需要 Claude 订阅账号）"'
    echo 'echo; echo ">>> 复制上面 sk-ant-oat… 开头的令牌，回到 App「全局设置 → Claude 令牌」粘贴后保存。"'
  elif [ "$WHICH" = "gpt" ]; then
    echo 'echo "============ 登录 ChatGPT（供 GPT / codex 使用）============"'
    echo 'echo "浏览器会打开 ChatGPT 登录；完成后凭据自动保存，无需复制 key。"; echo'
    echo 'codex login'
    echo 'echo; echo ">>> 登录完成后，回到 App「全局设置」点『重新检测』，GPT 那盏灯会变绿。"'
  else
    echo 'echo "用法: engine-login.sh <claude|gpt>"'
  fi
  echo 'echo; echo "（完成后可关闭本窗口）"'
} > "$TMP"
chmod +x "$TMP"
open "$TMP"
