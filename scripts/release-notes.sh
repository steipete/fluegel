#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
awk -v v="$version" '
  $0 ~ ("^## " v " - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$") { found=1; next }
  found && /^## / { exit }
  found && NF { started=1 }
  found && started { print }
  END { if (!started) exit 1 }
' CHANGELOG.md
