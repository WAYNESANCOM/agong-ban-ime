#!/bin/zsh
# 用 Developer ID 簽章並送 Apple 公證 build/BopomofoHalf.app
# 沙盒 App（例如 App Store 版 LINE）只接受有正式簽章的輸入法
# 需要環境變數：ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_PATH（App Store Connect API 金鑰）
set -euo pipefail
cd "$(dirname "$0")"
APP=build/BopomofoHalf.app
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')
[[ -n "$IDENTITY" ]] || { echo "NO_DEVELOPER_ID"; exit 1; }
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
ZIP=build/BopomofoHalf.zip
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"
spctl -a -vv -t install "$APP"
echo "NOTARIZE_OK $APP"
