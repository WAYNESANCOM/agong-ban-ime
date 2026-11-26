#!/bin/zsh
# 做出可雙擊安裝的 build/BopomofoHalf-<版本>.pkg（裝到 /Library/Input Methods）
# 需要：鑰匙圈裡的 Developer ID Application 與 Developer ID Installer 憑證，
#      以及 ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_PATH（公證用）
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
./build.sh
./notarize.sh
ROOT=build/pkgroot
rm -rf "$ROOT" && mkdir -p "$ROOT/Library/Input Methods"
ditto build/BopomofoHalf.app "$ROOT/Library/Input Methods/BopomofoHalf.app"
# 不做版本比對，舊的 1.x 測試版也能被這版蓋過去
pkgbuild --analyze --root "$ROOT" build/component.plist
/usr/libexec/PlistBuddy -c "Set :0:BundleIsVersionChecked false" build/component.plist
pkgbuild --root "$ROOT" --component-plist build/component.plist --scripts pkg-scripts \
  --identifier com.waynesan.inputmethod.BopomofoHalf.pkg --version "$VERSION" --install-location / build/component.pkg
INSTALLER_ID=$(security find-identity -v | awk -F'"' '/Developer ID Installer/ {print $2; exit}')
[[ -n "$INSTALLER_ID" ]] || { echo "NO_DEVELOPER_ID_INSTALLER"; exit 1; }
PKG="build/BopomofoHalf-$VERSION.pkg"
productbuild --package build/component.pkg --sign "$INSTALLER_ID" "$PKG"
rm -rf build/component.pkg build/component.plist "$ROOT"
xcrun notarytool submit "$PKG" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$PKG"
spctl -a -vv -t install "$PKG"
# build/ 裡那份 App 不能留著被系統登記，不然會跟裝好的那份打架
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/build/BopomofoHalf.app" || true
rm -rf build/BopomofoHalf.app
echo "PACKAGE_OK $PKG"
