#!/bin/zsh
# 建置 ㄅ半注音.app 到 build/
set -euo pipefail
cd "$(dirname "$0")"
APP=build/BopomofoHalf.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target arm64-apple-macos13 -framework Cocoa -framework Carbon -framework InputMethodKit \
  Sources/*.swift -o "$APP/Contents/MacOS/BopomofoHalf"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/ "$APP/Contents/Resources/"
swift tools/make_icon.swift "$APP/Contents/Resources/icon.tiff"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP" && echo "BUILD_OK $APP"
