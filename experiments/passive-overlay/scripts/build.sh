#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Codex Buddie.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -O -target "$(uname -m)-apple-macosx14.0" Sources/BuddieCore.swift Sources/BuddieView.swift Sources/SetupProgress.swift Sources/Onboarding.swift Sources/Theme.swift Sources/Studio.swift Sources/main.swift \
  -o "$APP/Contents/MacOS/CodexBuddie" -framework AppKit -framework CoreGraphics -framework ImageIO
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.sutureai.codex-buddie</string>
<key>CFBundleName</key><string>Codex Buddie</string>
<key>CFBundleDisplayName</key><string>Codex Buddie</string>
<key>CFBundleExecutable</key><string>CodexBuddie</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built %s (local ad-hoc signature; not notarized)\n' "$APP"
