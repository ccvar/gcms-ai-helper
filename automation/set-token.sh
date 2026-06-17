#!/bin/bash
# 保存 Claude 后台登录令牌（claude setup-token 生成）到项目内 .claude-auth.env
# run-daily.sh 会自动读取它，让"无界面"的每日撰稿用你自己的账号。
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN="$1"
ENV="$PROJ/.claude-auth.env"
if [ -z "$TOKEN" ]; then
  rm -f "$ENV"
  echo "已清除后台令牌"
  exit 0
fi
python3 - "$ENV" "$TOKEN" <<'PY'
import sys, os
p, tok = sys.argv[1], ''.join(sys.argv[2].split())  # 去掉粘贴时混入的换行/空格
open(p, 'w', encoding='utf-8').write(
    "# Claude 后台自动撰稿登录令牌（claude setup-token 生成）——勿提交 / 分享\n"
    "CLAUDE_CODE_OAUTH_TOKEN=" + tok + "\n")
os.chmod(p, 0o600)
PY
echo "✅ 令牌已保存（600 权限）"
