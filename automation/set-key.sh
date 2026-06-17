#!/bin/bash
# 更新当前活动站的 API 密钥（写入 sites/<slug>/site.env，随文件夹迁移）
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJ/automation/site.sh"   # 写到当前活动站的 key 文件
KEY="$1"
[ -z "$KEY" ] && { echo "用法: set-key.sh <API_KEY>"; exit 1; }
mkdir -p "$(dirname "$SITE_KEYFILE")"
python3 - "$SITE_KEYFILE" "$KEY" <<'PY'
import sys,os
p,key=sys.argv[1],sys.argv[2]
lines=[]
try: lines=open(p,encoding='utf-8').read().splitlines()
except FileNotFoundError: pass
out=[]; found=False
for l in lines:
    if l.startswith('CCVAR_API_KEY='):
        out.append('CCVAR_API_KEY='+key); found=True
    else:
        out.append(l)
if not found: out.append('CCVAR_API_KEY='+key)
open(p,'w',encoding='utf-8').write('\n'.join(out)+'\n')
os.chmod(p,0o600)
PY
echo "✅ 密钥已更新（已设 600 权限）。"
