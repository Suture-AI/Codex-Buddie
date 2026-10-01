#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Build first so this exercises the exact dylib shipped by the native preparer.
bash scripts/build.sh
frameworks="$PWD/.build/Codex Buddie Lab.app/Contents/Frameworks"
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -mmacosx-version-min=13.0 \
  tests/test_cursor_library.m -framework Cocoa -L"$frameworks" -lBuddie \
  -Wl,-rpath,"$frameworks" -o .build/test-cursor-library
.build/test-cursor-library
