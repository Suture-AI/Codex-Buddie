#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="$HOME/Applications/Codex Buddie.app"
if [ -e "$DEST" ]; then
  printf 'Already exists: %s\nMove your previous copy aside before installing this prototype.\n' "$DEST" >&2
  exit 1
fi
bash scripts/build.sh
mkdir -p "$HOME/Applications"
ditto 'build/Codex Buddie.app' "$DEST"
open "$DEST"
