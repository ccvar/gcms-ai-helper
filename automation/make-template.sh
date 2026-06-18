#!/bin/bash
# 产出「干净发行包」到 dist/：零站点、无密钥、无任何站点数据。
# 对方解压后，只需在 App 里配好 AI 引擎与自己的站点即可使用。
# 用法: bash automation/make-template.sh        # 输出到 <项目>/dist/
set -eu
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="CCVAR撰稿助手"
DIST="$PROJ/dist"
DEST="$DIST/$NAME"

echo "源: $PROJ"
echo "出: $DIST/"
rm -rf "$DIST"; mkdir -p "$DEST"

# 复制代码与资源；排除：版本库、所有站点数据、密钥、日志、运行缓存、备份、dist 自身
rsync -a \
  --exclude '.git' \
  --exclude '.github' \
  --exclude 'dist/' \
  --exclude 'sites/' \
  --exclude '*.env' \
  --exclude 'automation/logs/' \
  --exclude 'automation/.runstatus' \
  --exclude 'automation/.publishing' \
  --exclude 'automation/*.tsv' \
  --exclude 'drafts/' \
  --exclude '*.tgz' --exclude '*.zip' \
  --exclude 'build/err.txt' \
  "$PROJ/" "$DEST/"

# 零站点注册表
printf '{\n  "active": "",\n  "sites": []\n}\n' > "$DEST/sites.json"

# 全局配置重置为默认（不带作者的私有选择/缓存）
python3 - "$DEST/config.json" <<'PY'
import json, sys
json.dump({
    "draft_hour": 9, "draft_minute": 0,
    "writer_engine": "claude", "editor_engine": "claude",
    "model": "", "editor_model": "", "codex_model": "", "ai_cmd": "",
    "auto_daily_cap": 5,
}, open(sys.argv[1], "w"), ensure_ascii=False, indent=2)
PY

# 空 sites/ 占位（首次添加站点时自动建子目录）
mkdir -p "$DEST/sites"

# 给小白的快速开始
cat > "$DEST/快速开始.txt" <<'TXT'
CCVAR 撰稿助手 · 快速开始
============================

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 第一次打开（重要 · 只需做一次）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
本 App 没做苹果付费公证，首次打开时 macOS 会拦一下——
这是正常的安全提示，不是软件坏了。任选一种方式打开，之后就能正常双击：

【最省事】双击本文件夹里的「首次打开（解除拦截）.command」，
          它会自动解除拦截并打开 App。
          （若这个文件也被拦：右键点它 →「打开」→ 再点「打开」）

【手动】  右键点（或按住 Control 点）「CCVAR撰稿助手.app」
          →「打开」→ 弹窗里再点一次「打开」。

【macOS 15 及更新】若以上被拒绝：先双击一次 App（会被拦下），
          再到  系统设置 → 隐私与安全性 → 拉到底 → 点「仍要打开」。

打开后，屏幕顶部菜单栏右侧会出现一个小图标，点它即可使用。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

接着做这几步：

1) 点菜单栏图标 →「全局设置…」，配置 AI 引擎：
   · Claude：填访问令牌（终端运行  claude setup-token  生成），或先在终端登录 claude。
   · GPT：终端运行  codex login  用 ChatGPT 登录（有免费额度）；或填 OpenAI Key。
   面板下方两盏灯变【绿】= 配好了。

2) 点「站点管理…」→ 填【名称 / API 域名 / API 密钥】添加你的站点。
   域名形如 https://你的站.com/api/admin/v1 ；密钥需含 publish 权限才能发布。

3) 完成。之后每天自动撰稿；也可随时点「立刻撰稿一篇」。
   想自动发布：在「本站设置」把发布模式改成半自动 / 全自动。

需要帮助：菜单里「使用帮助（新手必读）…」。
TXT

# 首次打开助手：一键解除下载拦截并启动 App（省去右键→打开的麻烦）
cat > "$DEST/首次打开（解除拦截）.command" <<'CMD'
#!/bin/bash
# 双击我：自动解除「下载拦截」并打开 CCVAR撰稿助手。只需第一次用一下。
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "正在解除下载拦截并打开 CCVAR撰稿助手…"
xattr -dr com.apple.quarantine "$DIR" 2>/dev/null
if open "$DIR/CCVAR撰稿助手.app"; then
  echo "✅ 已打开！菜单栏右上角会出现图标。以后正常双击 App 即可，不用再点我。"
else
  echo "⚠ 自动打开失败，请改用：右键点 App →「打开」→ 再点「打开」。"
fi
echo; echo "按任意键关闭本窗口。"; read -n 1 -s
CMD
chmod +x "$DEST/首次打开（解除拦截）.command"

# 打包 zip
cd "$DIST"
zip -r -q -X "$NAME.zip" "$NAME"
cd "$PROJ"

echo
echo "✅ 发行包已生成于 dist/："
echo "   dist/$NAME/        ← 干净目录（可直接拷给别人）"
echo "   dist/$NAME.zip     ← 压缩包（$(du -h "$DIST/$NAME.zip" | cut -f1)）"
echo "   自检 ——"
if grep -rIl 'gcms_[A-Za-z0-9]\{16,\}' "$DEST" >/dev/null 2>&1; then echo "   ❌ 包里发现疑似密钥！"; else echo "   ✓ 未发现密钥"; fi
if ls "$DEST"/sites/*/ >/dev/null 2>&1; then echo "   ❌ 包里仍有站点数据！"; else echo "   ✓ 无站点数据（零配置）"; fi
[ -d "$DEST/$NAME.app" ] && echo "   ✓ App 已包含" || echo "   ⚠ 未找到 App"
