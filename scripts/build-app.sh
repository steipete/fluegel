#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Fluegel.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS"
cp ".build/release/FluegelMenu" "$MACOS/Fluegel"
cp ".build/release/fluegel" "$DIST/fluegel"
chmod +x "$MACOS/Fluegel" "$DIST/fluegel"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Fluegel</string>
  <key>CFBundleIdentifier</key>
  <string>me.steipete.Fluegel</string>
  <key>CFBundleName</key>
  <string>Fluegel</string>
  <key>CFBundleDisplayName</key>
  <string>Fluegel</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSRemindersUsageDescription</key>
  <string>Fluegel runs explicitly whitelisted commands that need Reminders access.</string>
  <key>NSRemindersFullAccessUsageDescription</key>
  <string>Fluegel runs explicitly whitelisted commands that need full Reminders access.</string>
</dict>
</plist>
PLIST

echo "APPL????" > "$CONTENTS/PkgInfo"
codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
echo "$DIST/fluegel"
