#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Build the dylib first with scripts/build.sh.
frameworks="$PWD/.build/Codex Buddie Lab.app/Contents/Frameworks"
xcrun swiftc -import-objc-header Sources/BuddieView.h tests/test_native_layout.swift \
  -framework Cocoa -framework SwiftUI -L"$frameworks" -lBuddie \
  -Xlinker -rpath -Xlinker "$frameworks" -o .build/test-native-layout
.build/test-native-layout
