# Fluegel

Fluegel is a tiny macOS menu bar permission bridge for commands that need GUI-owned TCC permissions.

Initial scope:

- Reminders permission only.
- Exact full-path command whitelist.
- CLI requests go through the menu bar app.
- Whitelist edits require local user authentication.
- Command runs are appended to an audit log.

## Build

```bash
swift test
scripts/build-app.sh
```

Artifacts:

- `dist/Fluegel.app`
- `dist/fluegel`

## Use

Start the app once:

```bash
open dist/Fluegel.app
```

Allow `rem` after authenticating in the GUI session:

```bash
dist/fluegel allow add --path /opt/homebrew/bin/rem --permission reminders --name rem
dist/fluegel permissions request reminders
dist/fluegel run -- /opt/homebrew/bin/rem lists -o json
```
