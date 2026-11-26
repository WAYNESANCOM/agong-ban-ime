#!/bin/zsh
# 裝到 ~/Library/Input Methods 並啟用
set -euo pipefail
cd "$(dirname "$0")"
if [[ -d "/Library/Input Methods/BopomofoHalf.app" ]]; then
  echo "這台電腦已經用安裝檔裝在 /Library/Input Methods，請改用新版安裝檔更新，避免裝成兩份"
  exit 1
fi
./build.sh
# 有 Developer ID 憑證和 App Store Connect 金鑰時，順便簽章公證（沙盒 App 才切得過去）
if [[ -n "${ASC_KEY_ID:-}" ]]; then ./notarize.sh; fi
DEST="$HOME/Library/Input Methods/BopomofoHalf.app"
pkill -x BopomofoHalf || true
rm -rf "$DEST"
cp -R build/BopomofoHalf.app "$DEST"
# 系統只能認一份：把 build/ 裡那份從 LaunchServices 移除並刪掉，不然沙盒 App 會被拒絕連線
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSR" -u "$PWD/build/BopomofoHalf.app" || true
rm -rf build/BopomofoHalf.app
"$LSR" -f "$DEST"
swift tools/register.swift "$DEST"
echo "INSTALL_OK $DEST"
