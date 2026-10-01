#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun swiftc Sources/BuddieCore.swift Tests/CoreTests.swift -o .build/core-tests -framework CoreGraphics -framework ImageIO
.build/core-tests
