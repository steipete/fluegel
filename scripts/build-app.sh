#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Fluegel.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

cd "$ROOT"
build_args=(-c release)
if [[ "${1:-}" == "--universal" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--universal]" >&2
  exit 2
fi
swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
version="$(sed -nE 's/.*static let current = "([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' Sources/FluegelCore/Version.swift)"
[[ -n "$version" ]]

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$bin_dir/FluegelMenu" "$MACOS/Fluegel"
cp "$bin_dir/fluegel" "$DIST/fluegel"
chmod +x "$MACOS/Fluegel" "$DIST/fluegel"

cat > "$CONTENTS/Info.plist" <<PLIST
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
  <string>$version</string>
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
