# Troubleshooting and data locations

## The CLI cannot connect

Start Fluegel in the logged-in GUI session and retry:

```bash
open ~/Applications/Fluegel.app
fluegel status
```

If the app is installed elsewhere, pass its actual path to `open`.

## Reminders is not authorized

Check the current state:

```bash
fluegel permissions status reminders
```

If the result is `notDetermined`, request access and approve the macOS prompt:

```bash
fluegel permissions request reminders
```

Rebuilding, moving, or signing the app with a different identity can make macOS treat it as a different TCC client. Request access again if the status resets.

## A command is denied

Inspect the exact stored paths and recent decisions:

```bash
fluegel allow list
fluegel audit list --limit 10
```

The run path must be absolute and match an enabled whitelist entry exactly. The entry must include every permission it needs, and those permissions must currently be authorized.

## Data locations

Fluegel stores its configuration, bridge token, and socket under:

```text
~/Library/Application Support/Fluegel/
```

The append-only audit log is stored at:

```text
~/Library/Logs/Fluegel/audit.jsonl
```

These are plain local app files intended for debugging. The directories use mode `0700`, and the stored files and socket use mode `0600`.
