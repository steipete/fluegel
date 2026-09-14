# Changelog

## Unreleased

## 0.1.0 - 2026-09-14

**Highlights:** Timed-out commands now stop surviving child processes, and Reminders permission requests build correctly with older EventKit SDK annotations.

- Add signed and notarized universal macOS downloads and a `fluegel --version` command.
- Fix timed-out commands leaving child processes running when their parent exits on SIGTERM.
- Fix Swift 6 builds with older EventKit SDK annotations by keeping Reminders permission requests on the main actor.
