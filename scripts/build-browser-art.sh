#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter \
  scripts/export-browser-bit.m -framework Cocoa \
  -L'.build/Codex Buddie Lab.app/Contents/Frameworks' -lBuddie \
  -Wl,-rpath,'@executable_path/Codex Buddie Lab.app/Contents/Frameworks' \
  -o .build/export-browser-bit
.build/export-browser-bit Characters/bit browser-extension/assets
python3 - <<'PY'
import json
from pathlib import Path
p=Path('browser-extension/assets')
atlas=json.loads((p/'bit-atlas.json').read_text())
(p/'atlas.js').write_text('globalThis.BuddieBitAtlas = '+json.dumps(atlas,separators=(',',':'))+';\n')
PY
