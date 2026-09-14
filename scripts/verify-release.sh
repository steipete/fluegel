#!/usr/bin/env bash
set -euo pipefail
version="${1#v}"
asset_dir="$(cd "$2" && pwd)"
(cd "$asset_dir" && shasum -a 256 -c checksums.txt)
stage="$(mktemp -d "${TMPDIR:-/tmp}/fluegel-verify.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto -x -k "$asset_dir/fluegel-macos.zip" "$stage"
app="$stage/Fluegel.app"
cli="$stage/fluegel"
for path in "$app" "$cli"; do
  if [[ "$path" == "$app" ]]; then identifier=me.steipete.Fluegel; else identifier=me.steipete.fluegel; fi
  codesign --verify --deep --strict -R="identifier \"$identifier\" and anchor apple generic and certificate leaf[subject.OU] = \"Y5PE65HELJ\"" "$path"
  codesign --display --verbose=2 "$path"
done
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
codesign --verify --strict --check-notarization -R=notarized "$cli"
for binary in "$cli" "$app/Contents/MacOS/Fluegel"; do
  for arch in arm64 x86_64; do
    lipo "$binary" -verify_arch "$arch"
    otool -arch "$arch" -l "$binary" | awk '/LC_BUILD_VERSION/ { build=1 } build && /minos/ { if ($2 != "14.0") exit 1; found=1; exit } END { if (!found) exit 1 }'
  done
done
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")" == 14.0 ]]
[[ "$("$cli" --version)" == "$version" ]]
"$cli" --help
