# Fluegel

Fluegel is a small macOS menu bar app that lets automation agents run approved
CLI tools through a GUI process that owns macOS privacy permissions.

The first supported use case is Apple Reminders via
[`rem`](https://github.com/BRO3886/rem). A headless agent can ask Fluegel to run
`/opt/homebrew/bin/rem`, while macOS sees the access as coming from
`Fluegel.app`, not from the agent's shell, SSH session, terminal emulator, or
temporary helper process.

## Why

macOS TCC permissions are tied to the app or binary that requests them. That is
good for users, but awkward for local AI agents:

- The agent may run from Codex, SSH, Ghostty, launchd, or another transient
  process.
- Granting every possible caller Reminders access is brittle and hard to audit.
- Apple Reminders has no official automation-friendly API or CLI.
- Tools like `rem` work well, but only from a process that has the right TCC
  grant.

Fluegel gives that permission a stable home. You grant Reminders once to the
menu bar app, then allow only specific full-path commands to use it.

## Current Scope

- macOS menu bar app with a simple settings window.
- Reminders permission only.
- Exact full-path command whitelist.
- CLI bridge for status, permission requests, whitelist edits, execution, and
  audit reads.
- Local user authentication for whitelist changes.
- Append-only audit log for allowed and denied command runs.

## Build

```bash
swift test
scripts/build-app.sh
```

Build artifacts:

- `dist/Fluegel.app`
- `dist/fluegel`

## Install Locally

```bash
scripts/build-app.sh
mkdir -p ~/Applications
cp -R dist/Fluegel.app ~/Applications/
install -m 755 dist/fluegel /opt/homebrew/bin/fluegel
open ~/Applications/Fluegel.app
```

For the current clawmac deployment path:

```bash
scripts/deploy-clawmac.sh steipete@clawmac
```

## Quick Start With rem

Start Fluegel in the GUI session:

```bash
open ~/Applications/Fluegel.app
```

Request Reminders permission:

```bash
fluegel permissions request reminders
```

Add `rem` to the whitelist. This requires local user authentication on the Mac
running Fluegel:

```bash
fluegel allow add --path /opt/homebrew/bin/rem --permission reminders --name rem
```

Run `rem` through Fluegel:

```bash
fluegel run -- /opt/homebrew/bin/rem lists --output json
fluegel run -- /opt/homebrew/bin/rem add "Book LHR to SFO flight"
fluegel run -- /opt/homebrew/bin/rem today
```

## CLI

```bash
fluegel status
fluegel run -- /full/path [args...]
fluegel allow list
fluegel allow add --path /full/path --permission reminders [--name name]
fluegel allow remove --path /full/path
fluegel permissions status reminders
fluegel permissions request reminders
fluegel audit list [--limit n]
```

All executable paths must be absolute. Arguments after the executable are passed
through to the whitelisted command.

## Settings UI

Open the menu bar app and choose settings. The window has three tabs:

- `Permissions`: shows Reminders status and can request access.
- `Whitelist`: adds, updates, or removes full-path command entries.
- `Audit`: shows recent allowed and denied runs.

When Reminders access is granted, the Permissions tab shows `Granted`.

## Security Model

Fluegel is intentionally narrow:

- The bridge listens on a private Unix domain socket in Fluegel's application
  support directory.
- The CLI must present a local token created by the app.
- Commands are matched by exact executable path.
- Whitelist edits require macOS local authentication.
- Runs are denied when the command is not whitelisted, disabled, or asks for a
  permission Fluegel does not currently have.
- Every allow/deny decision is written to the audit log with the executable,
  arguments, requester, permissions, result size, exit code, and reason.

This is a convenience boundary for trusted local automation. It is not a
sandbox, not a privilege escalation framework, and not meant to run arbitrary
user input.

## Data Locations

Fluegel stores its config, token, and socket under:

```text
~/Library/Application Support/Fluegel/
```

The audit log is written separately under:

```text
~/Library/Logs/Fluegel/audit.jsonl
```

The current files are implementation details, but they are plain local app data
and can be inspected while debugging.

## Troubleshooting

Check that the app is running:

```bash
fluegel status
```

If the CLI cannot connect, start the app in the logged-in GUI session:

```bash
open ~/Applications/Fluegel.app
```

Check Reminders permission:

```bash
fluegel permissions status reminders
```

If it says `notDetermined`, request access and approve the macOS prompt:

```bash
fluegel permissions request reminders
```

If a command is denied, inspect the whitelist and audit log:

```bash
fluegel allow list
fluegel audit list --limit 10
```

After rebuilding or re-signing the app, macOS may treat it as a new TCC client.
Request Reminders access again if the status resets.

## Status

Early project. The first practical target is reliable Reminders automation via
`rem`. Future permissions should stay explicit and narrow, with the same
full-path whitelist and audit-first behavior.
