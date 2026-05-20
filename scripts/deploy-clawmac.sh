#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-steipete@clawmac}"
REMOTE="/Users/steipete/Projects/fluegel"

ssh -o RequestTTY=no -o RemoteCommand=none "$HOST" 'zsh -lc "mkdir -p ~/Projects"'
ssh -o RequestTTY=no -o RemoteCommand=none "$HOST" "zsh -lc 'if [ -d \"$REMOTE/.git\" ]; then cd \"$REMOTE\" && git pull --ff-only; else git clone git@github.com:steipete/fluegel.git \"$REMOTE\"; fi'"
ssh -o RequestTTY=no -o RemoteCommand=none "$HOST" "zsh -lc 'cd \"$REMOTE\" && scripts/build-app.sh && rm -rf ~/Applications/Fluegel.app && mkdir -p ~/Applications && cp -R dist/Fluegel.app ~/Applications/Fluegel.app && install -m 0755 dist/fluegel /opt/homebrew/bin/fluegel && open ~/Applications/Fluegel.app && /opt/homebrew/bin/fluegel status'"
