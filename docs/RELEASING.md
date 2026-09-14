# Releasing

Fluegel ships one universal macOS archive containing `Fluegel.app` and `fluegel`, plus `checksums.txt`, on GitHub Releases. Both support macOS 14 or later on Apple Silicon and Intel. There is no Homebrew, npm, or Sparkle publication step.

The release follows remindctl's tag-driven universal Swift packaging path, with Developer ID signing and notarization in GitHub Actions. The app keeps bundle identifier `me.steipete.Fluegel`; the CLI uses `me.steipete.fluegel`. Both are signed as `Developer ID Application: Peter Steinberger (Y5PE65HELJ)`. The workflow imports its signer into an ephemeral runner keychain and restores the original search list during cleanup.

## Preparation

1. Set `FluegelVersion.current` in `Sources/FluegelCore/Version.swift`. The CLI and generated app metadata use this same value. Increment `CFBundleVersion` in `scripts/build-app.sh` for each release.
2. Finalize the changelog with a dated `## X.Y.Z - YYYY-MM-DD` section. Keep the Highlights line first; the workflow publishes this section's body verbatim.
3. Update the README download links and run `scripts/check.sh`, `shellcheck scripts/*.sh`, and `actionlint`. The local gate runs every Swift test, builds both architectures, validates the app metadata/signature, and smoke-tests CLI version/help and invalid paths. It does not launch the app or change privacy grants.
4. Run independent review through P2, open a PR, and squash-merge after CI passes. Wait for the `CI` push run on the exact resulting `main` commit to pass.

The repository needs these Actions secrets: `MACOS_SIGNING_P12` (base64 personal Developer ID PKCS#12), `MACOS_SIGNING_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY_P8`. Populate them through the approved release credential store; never commit credentials.

## Tag and publish

Confirm the version has no existing tag or GitHub Release immediately before tagging. Create a signed annotated tag at the green `main` commit and push it:

```bash
git tag -s vX.Y.Z -m 'Release vX.Y.Z'
git push origin vX.Y.Z
```

The `Release` workflow verifies that the annotated tag equals `main` and that independent CI passed at that exact commit. It rebuilds and tests both architectures, signs both payloads with the hardened runtime and a secure timestamp, notarizes their archive, staples the app ticket, and generates checksums. Independent Apple Silicon and Intel jobs verify the exact artifact, notarization, signing identity, version, and minimum deployment target before publication. Neither job launches the GUI app.

Publication creates a new release and refuses to overwrite an existing one. Before publication, a transient failed job can be rerun; a full retry can also use `workflow_dispatch` with the existing tag while `main` is unchanged. Never move a published tag.

## Verification and closeout

Download the release archive and checksums, then run:

```bash
scripts/verify-release.sh vX.Y.Z /path/to/downloads
```

The verifier checks checksums, both architectures and deployment targets, the exact signing Team and identifiers, stapled app ticket, app Gatekeeper assessment, CLI online notarization, and native `--version`. Apple does not support stapling standalone CLI tickets; use the online `codesign --check-notarization` constraint for the CLI. On newer macOS, raw CLI `spctl` assessments can reject correctly notarized executables because they are not app bundles.

Verify the release body matches `scripts/release-notes.sh vX.Y.Z`, then open an empty `## Unreleased` section at the top of the changelog for the next patch, review and land it, and leave clean `main` synchronized with the remote.
