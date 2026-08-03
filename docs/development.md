# Development notes

## Build and test

```bash
swift test
scripts/build-app.sh
```

The packaging script makes a release build, creates `dist/Fluegel.app`, copies the CLI to `dist/fluegel`, writes the app metadata, and ad-hoc signs the bundle.

For local testing against saved privacy grants, sign the app with the same persistent signing identity used for that installation before launching it. Changing the bundle's signing identity may reset its TCC grants.

## Deploy to clawmac

The repository includes a helper for the current clawmac deployment path:

```bash
scripts/deploy-clawmac.sh steipete@clawmac
```

The helper updates or clones `/Users/steipete/Projects/fluegel` on the target, builds the app, installs the app and CLI, opens the app in the GUI session, and checks `fluegel status`. It assumes SSH access and permission to write `/opt/homebrew/bin/fluegel` on the target.
