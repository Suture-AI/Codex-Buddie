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
# A certificate keeps the designated requirement stable across rebuilds, so
# macOS can associate updated code with an existing privacy permission grant.
SIGN_IDENTITY="${BUDDIE_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  identities=()
  while IFS= read -r identity; do
    [[ -n "$identity" ]] && identities+=("$identity")
  done < <(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development:/ {print $2}' || true)
  if [[ ${#identities[@]} -eq 1 ]]; then
    SIGN_IDENTITY="${identities[0]}"
  else
    SIGN_IDENTITY="-"
    printf 'No unique Apple Development identity. Set BUDDIE_SIGN_IDENTITY to select a certificate.\n' >&2
  fi
fi
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  printf 'Built %s (ad-hoc signed; updates may require granting screen access again; not notarized)\n' "$APP"
else
  printf 'Built %s (certificate signed; not notarized)\n' "$APP"
fi
