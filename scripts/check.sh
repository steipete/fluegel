#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
scripts/build-app.sh --universal
plutil -lint dist/Fluegel.app/Contents/Info.plist
codesign --verify --deep --strict dist/Fluegel.app
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/Fluegel.app/Contents/Info.plist)"
[[ "$(dist/fluegel --version)" == "$version" ]]
for binary in dist/fluegel dist/Fluegel.app/Contents/MacOS/Fluegel; do
  for arch in arm64 x86_64; do
    lipo "$binary" -verify_arch "$arch"
  done
done
dist/fluegel --help
exit_code=0
output=$(dist/fluegel run -- relative-path 2>&1) || exit_code=$?
[[ "$exit_code" -eq 2 && "$output" == 'usage: fluegel run -- /full/path [args...]' ]]
