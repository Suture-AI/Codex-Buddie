#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun clang -std=c11 -Wall -Wextra Sources/BuddieMotion.c tests/test_motion.c -lm -o .build/test-motion
.build/test-motion
xcrun clang -fobjc-arc -fmodules -Wall -Wextra Sources/BuddieCharacter.m tests/test_character.m -framework Cocoa -o .build/test-character
.build/test-character
xcrun clang -fobjc-arc -fmodules -Wall -Wextra Sources/BuddieCharacter.m Sources/BuddieLibrary.m tests/test_library.m -framework Cocoa -o .build/test-library
.build/test-library
