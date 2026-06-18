#!/bin/bash
# 从源码构建菜单栏 app 到 <项目>/CCVAR撰稿助手.app。
# 优先产出通用二进制（arm64 + x86_64，兼容 Apple Silicon 与 Intel）；交叉编译失败则退回本机架构。
# 图标为尽力而为：生成失败不影响 app 运行。最后做临时(ad-hoc)签名。
# 用法: bash build/build-app.sh        # 需要 macOS + swiftc
set -eu
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="CCVAR撰稿助手"
APP="$PROJ/$NAME.app"
cd "$PROJ/build"

echo "==> 编译 menubar.swift"
if swiftc menubar.swift -target arm64-apple-macos12  -o /tmp/helper-arm64  2>/tmp/sw-arm.log \
&& swiftc menubar.swift -target x86_64-apple-macos12 -o /tmp/helper-x86_64 2>/tmp/sw-x86.log; then
  lipo -create -output CCVARHelper /tmp/helper-arm64 /tmp/helper-x86_64
  echo "    通用二进制：$(lipo -archs CCVARHelper)"
else
  echo "    交叉编译不可用，改用本机架构 ($(uname -m)) @ macos12"
  swiftc menubar.swift -target "$(uname -m)-apple-macos12" -o CCVARHelper
fi

echo "==> 组装 $NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp CCVARHelper "$APP/Contents/MacOS/CCVARHelper"
cp Info.plist  "$APP/Contents/Info.plist"
cp "$PROJ/assets/"favicon*.svg "$APP/Contents/Resources/" 2>/dev/null || true

echo "==> 生成应用图标（尽力而为）"
if swiftc make_appicon.swift -o /tmp/mkicon 2>/dev/null \
&& /tmp/mkicon "$PROJ/assets/favicon.svg" /tmp/icon1024.png 2>/dev/null \
&& [ -s /tmp/icon1024.png ]; then
  ICONSET=/tmp/AppIcon.iconset; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s"               /tmp/icon1024.png --out "$ICONSET/icon_${s}x${s}.png"    >/dev/null 2>&1 || true
    sips -z "$((s*2))" "$((s*2))"   /tmp/icon1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    echo "    图标已生成"
  else
    echo "    （图标打包失败，使用系统默认，不影响使用）"
  fi
else
  echo "    （未能渲染图标，使用系统默认，不影响使用）"
fi

echo "==> 临时签名 (ad-hoc)"
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true

echo "✅ 已构建：$APP"
