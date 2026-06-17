#!/bin/bash
# CCVAR 自动撰稿 —— 一键安装/重装。可在任意一台 Mac 上运行。
# 用法：把整个项目文件夹拷过去，然后  bash automation/install.sh
set -u
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LA="$HOME/Library/LaunchAgents"
APP="$PROJ/CCVAR撰稿助手.app"
mkdir -p "$LA" "$PROJ/automation/logs"

# 读取撰稿时间（默认 8:00）
HH=8; MM=0
if [ -f "$PROJ/config.json" ]; then
  HH=$(python3 -c 'import json;print(json.load(open("'"$PROJ"'/config.json")).get("draft_hour",8))' 2>/dev/null || echo 8)
  MM=$(python3 -c 'import json;print(json.load(open("'"$PROJ"'/config.json")).get("draft_minute",0))' 2>/dev/null || echo 0)
fi
echo "项目目录: $PROJ"
printf "撰稿时间: %02d:%02d\n" "$HH" "$MM"

# 1) 每日撰稿定时器
cat > "$LA/com.ccvar.dailydraft.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ccvar.dailydraft</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$PROJ/automation/run-daily-all.sh</string></array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$HH</integer><key>Minute</key><integer>$MM</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$PROJ/automation/logs/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$PROJ/automation/logs/launchd.err.log</string>
</dict></plist>
EOF

# 2) 菜单栏 App 登录自启
cat > "$LA/com.ccvar.menubar.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ccvar.menubar</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>$APP</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF

# 2.5) 全自动发布巡检（每小时一次；仅「全自动」模式且过了否决窗口才会发）
cat > "$LA/com.ccvar.publish.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ccvar.publish</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$PROJ/automation/publish-pending.sh</string></array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$PROJ/automation/logs/publish.out.log</string>
  <key>StandardErrorPath</key><string>$PROJ/automation/logs/publish.err.log</string>
</dict></plist>
EOF

# 3) App：有现成的就重新签名；否则用源码现编译（需要 swiftc）
if [ -d "$APP" ]; then
  [ -d "$PROJ/assets" ] && mkdir -p "$APP/Contents/Resources" && cp "$PROJ/assets/"favicon*.svg "$APP/Contents/Resources/" 2>/dev/null
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
elif command -v swiftc >/dev/null 2>&1 && [ -f "$PROJ/build/menubar.swift" ]; then
  echo "本机现编译菜单栏 App…"
  ( cd "$PROJ/build" \
    && swiftc menubar.swift -o CCVARHelper \
    && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" \
    && cp CCVARHelper "$APP/Contents/MacOS/" \
    && cp Info.plist "$APP/Contents/Info.plist" \
    && { [ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/"; } \
    && { cp "$PROJ/assets/"favicon*.svg "$APP/Contents/Resources/" 2>/dev/null || true; } \
    && codesign --force --deep -s - "$APP" ) || echo "（App 编译失败，可稍后重试；定时器不受影响）"
else
  echo "（未找到 App，也没有 swiftc；菜单栏工具可选，定时撰稿不受影响）"
fi

# 4) 加载
launchctl unload "$LA/com.ccvar.dailydraft.plist" 2>/dev/null || true
launchctl load -w "$LA/com.ccvar.dailydraft.plist"
launchctl unload "$LA/com.ccvar.menubar.plist" 2>/dev/null || true
launchctl load -w "$LA/com.ccvar.menubar.plist"
launchctl unload "$LA/com.ccvar.publish.plist" 2>/dev/null || true
launchctl load -w "$LA/com.ccvar.publish.plist"
# 预热语种缓存（设置页「写作/译文语种」用）
bash "$PROJ/automation/refresh-langs.sh" >/dev/null 2>&1 || true
[ -d "$APP" ] && open "$APP" 2>/dev/null || true

printf "✅ 安装完成：每天 %02d:%02d 自动撰稿；菜单栏助手已启动。\n" "$HH" "$MM"
