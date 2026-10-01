#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then echo 'macOS is required.' >&2; exit 1; fi
app="$PWD/.build/Codex Buddie Lab.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 \
  -dynamiclib Sources/BuddieView.m Sources/BuddieCharacter.m Sources/BuddieMotion.c Sources/Inject.m -framework Cocoa \
  -install_name @rpath/libBuddie.dylib -o "$app/Contents/Frameworks/libBuddie.dylib"
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 \
  Sources/Preview.m -framework Cocoa -L"$app/Contents/Frameworks" -lBuddie \
  -Wl,-rpath,@executable_path/../Frameworks -o "$app/Contents/MacOS/BuddieLab"
mkdir -p "$app/Contents/Resources"
if [[ -d Characters ]]; then rsync -a --delete Characters/ "$app/Contents/Resources/Characters/"; fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>ai.suture.codex-buddie.preview</string>
<key>CFBundleName</key><string>Codex Buddie Lab</string>
<key>CFBundleExecutable</key><string>BuddieLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$app/Contents/Frameworks/libBuddie.dylib"
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
