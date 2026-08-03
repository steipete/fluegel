# Security model

Fluegel gives trusted local automation a stable process for macOS privacy grants. It narrows which executables may use those grants, but it does not isolate approved processes from the user account or the rest of the system.

## Request flow

1. The menu bar app creates a Unix domain socket in its private application-support directory.
2. The CLI reads a per-user token from that directory and includes it in each request.
3. The app rejects an invalid token, an unknown or disabled executable path, an entry without permissions, or a permission that is not currently authorized.
4. Accepted commands run as the current user, and the result is returned to the CLI.
5. Both allowed and denied run decisions are appended to the audit log.

## Local protections

- The application-support and log directories are created with mode `0700`.
- The bridge socket, token, configuration, and audit log use mode `0600`.
- Whitelist matching uses the exact absolute executable path.
- Whitelist additions, updates, and removals require macOS device-owner authentication.
- Audit entries record the executable, arguments, requester, requested permissions, output sizes, exit code, decision, and reason.

## Limits

Fluegel is not a sandbox, an authorization service for untrusted users, or a privilege-escalation mechanism.

- Any process running as the same user may be able to read the local token and app data, subject to filesystem permissions.
- An exact path match does not pin the executable's code identity or prevent that file from being replaced.
- Approved commands inherit the app's environment and privacy grants and can access anything the current user can access.
- Command arguments are written to the audit log. Do not pass secrets on the command line.
- Fluegel checks declared privacy permissions before launch; it does not inspect or constrain what an approved executable does afterward.

Use OS-level isolation when the caller or executed program is hostile.
