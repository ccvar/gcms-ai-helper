#!/bin/bash
# 卸载：移除定时器与菜单栏自启（项目文件、草稿、密钥都保留）
LA="$HOME/Library/LaunchAgents"
launchctl unload "$LA/com.ccvar.dailydraft.plist" 2>/dev/null
launchctl unload "$LA/com.ccvar.menubar.plist" 2>/dev/null
pkill -x CCVARHelper 2>/dev/null
rm -f "$LA/com.ccvar.dailydraft.plist" "$LA/com.ccvar.menubar.plist"
echo "✅ 已卸载定时器与菜单栏助手（项目文件保留）。"
