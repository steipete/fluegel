# CLI reference

The `fluegel` CLI talks to the Fluegel menu bar app over its local bridge. Start the app in the logged-in GUI session before using commands other than `--help`.

## Commands

```text
fluegel status
fluegel run -- /full/path [args...]
fluegel allow list
fluegel allow add --path /full/path --permission reminders [--name name]
fluegel allow remove --path /full/path
fluegel permissions status reminders
fluegel permissions request reminders
fluegel audit list [--limit n]
```

`fluegel help`, `fluegel --help`, and `fluegel -h` print this command list.

## Status

```bash
fluegel status
```

The command prints `ok` followed by the number of whitelist entries when the bridge is reachable and the local token is accepted.

## Run

```bash
fluegel run -- /full/path [args...]
```

The executable path must be absolute and match an enabled whitelist entry exactly. Arguments after the executable are passed through unchanged. The child process inherits Fluegel's environment, uses the CLI's current directory, and has a 30-second default timeout.

On timeout, Fluegel sends SIGTERM to the command's process group, waits up to two seconds for the parent to exit, then sends SIGKILL to any remaining group members. Children that ignore SIGTERM are also stopped when their parent exits first.

The separator is optional, but it makes the boundary between Fluegel's arguments and the child command clear.

## Whitelist

```bash
fluegel allow list
fluegel allow add --path /full/path --permission reminders [--name name]
fluegel allow remove --path /full/path
```

Adding an existing path updates its entry. The app requires local device-owner authentication before adding, updating, or removing an entry. Reminders is currently the only accepted permission name.

## Permissions

```bash
fluegel permissions status reminders
fluegel permissions request reminders
```

`status` prints the current EventKit authorization state. `request` asks macOS for full Reminders access and may display a system prompt.

## Audit

```bash
fluegel audit list
fluegel audit list --limit 10
```

The command prints recent decisions newest first. Each line includes the timestamp, decision, executable path, and reason. The limit must be a positive integer and defaults to 20.

## Exit behavior

- `0` means the requested bridge operation succeeded.
- `1` means the app rejected the operation or the bridge failed. `run` instead returns the child command's exit code when the child starts.
- `2` means the CLI arguments were invalid.
