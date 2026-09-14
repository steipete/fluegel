#!/usr/bin/env bash
# Run on the ephemeral GitHub Actions runner after importing its release identity.
set -euo pipefail
set +x
cd "$(dirname "$0")/.."
: "${IDENTITY:?}" "${KEYCHAIN:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY_P8:?}" "${RUNNER_TEMP:?}"
version="${1#v}"
[[ "$(dist/fluegel --version)" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/Fluegel.app/Contents/Info.plist)" == "$version" ]]
app=dist/Fluegel.app
cli=dist/fluegel
team=Y5PE65HELJ
for path in "$cli" "$app"; do
  if [[ "$path" == "$app" ]]; then identifier=me.steipete.Fluegel; else identifier=me.steipete.fluegel; fi
  requirement="identifier \"$identifier\" and anchor apple generic and certificate leaf[subject.OU] = \"$team\""
  codesign --force --timestamp --options runtime --identifier "$identifier" \
    --requirements "=designated => $requirement" --keychain "$KEYCHAIN" --sign "$IDENTITY" "$path"
  codesign --verify --strict -R="$requirement" "$path"
done
p8="$RUNNER_TEMP/fluegel-notary.p8"
trap 'rm -f "$p8"' EXIT
umask 077
printf '%s' "$ASC_PRIVATE_KEY_P8" > "$p8"
unset ASC_PRIVATE_KEY_P8
stage="$(mktemp -d "$RUNNER_TEMP/fluegel-payload.XXXXXX")"
trap 'rm -f "$p8"; rm -rf "$stage"' EXIT
ditto "$app" "$stage/Fluegel.app"
cp "$cli" "$stage/fluegel"
mkdir -p dist/release
ditto --norsrc -c -k "$stage" dist/release/fluegel-macos.zip
xcrun notarytool submit dist/release/fluegel-macos.zip --key "$p8" --key-id "$ASC_KEY_ID" \
  --issuer "$ASC_ISSUER_ID" --no-s3-acceleration --wait --output-format json > "$RUNNER_TEMP/fluegel-notary.json"
if [[ "$(jq -r .status "$RUNNER_TEMP/fluegel-notary.json")" != Accepted ]]; then
  echo "Notarization was not accepted" >&2
  cat "$RUNNER_TEMP/fluegel-notary.json"
  exit 1
fi
xcrun stapler staple "$stage/Fluegel.app"
xcrun stapler validate "$stage/Fluegel.app"
codesign --verify --strict --check-notarization -R=notarized "$stage/fluegel"
spctl --assess --type execute --verbose=2 "$stage/Fluegel.app"
rm dist/release/fluegel-macos.zip
ditto --norsrc -c -k "$stage" dist/release/fluegel-macos.zip
(cd dist/release && shasum -a 256 fluegel-macos.zip > checksums.txt)
scripts/release-notes.sh "$version" > dist/release/RELEASE-NOTES.md
