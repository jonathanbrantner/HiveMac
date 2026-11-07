#!/bin/bash
# Builds the native HiveMac.app into swift/build/ (signed ad hoc). It does NOT install anything,
# so it never touches /Applications.
# Usage: swift/scripts/make-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(cd .. && pwd)"

APP_NAME="HiveMac"
BUNDLE_ID="app.hivemac.native"      # 
VERSION="$(tr -d '[:space:]' < "$REPO/VERSION")"
APP="build/${APP_NAME}.app"
RES="$APP/Contents/Resources"

swift build -c release --product HiveMac
BIN="$(swift build -c release --show-bin-path)/HiveMac"

rm -rf "$APP" "build/${APP_NAME}.iconset"
mkdir -p "$APP/Contents/MacOS" "$RES/paths"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"

# Natro's routes and the default settings ship inside the app.
rsync -a "$REPO/config/paths/natro/" "$RES/paths/"
mkdir -p "$RES/images" && rsync -a "$REPO/config/images/natro/" "$RES/images/"
mkdir -p "$RES/hud" && rsync -a "$REPO/config/images/hud/" "$RES/hud/"
cp "$REPO/config/quests.json" "$RES/quests.json"
cp "$REPO/config/default_config.json" "$RES/default_config.json"

# Icon: the HiveMac honeycomb.
swift "$REPO/scripts/make-icon.swift" "build/${APP_NAME}.iconset"
iconutil -c icns "build/${APP_NAME}.iconset" -o "$RES/${APP_NAME}.icns"
rm -rf "build/${APP_NAME}.iconset"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIconFile</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT licence. Not affiliated with Roblox.</string>
</dict>
</plist>
PLIST

# Sign with a real identity when one is on this Mac (an Apple Development certificate, free with any Apple ID).
# macOS then keeps Screen Recording and Accessibility across rebuilds. Without one, sign ad hoc, and the
# permissions have to be granted again after every build.
IDENTITY="${HIVEMAC_SIGN_IDENTITY:-$(security find-identity -p codesigning 2>/dev/null | grep -m1 'Apple Development' | awk '{print $2}')}"
if [ -n "$IDENTITY" ]; then
    echo "Signing with identity $IDENTITY"
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "No signing identity found, signing ad hoc (permissions reset after each build)"
    codesign --force --sign - "$APP"
fi
echo "Built swift/$APP ($(du -sh "$APP" | cut -f1))"
