#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
open "$PWD/.build/Codex Buddie Lab.app"
