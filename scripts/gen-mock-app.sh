#!/usr/bin/env bash
# Generate a minimal macOS .app bundle fixture for pipeline testing.
# Output: fixtures/mock-game-macos/MockWindowGame.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/fixtures/mock-game-macos/MockWindowGame.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/assets"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>game</string>
  <key>CFBundleIdentifier</key>
  <string>com.maxion.mockwindowgame</string>
  <key>CFBundleName</key>
  <string>MockWindowGame</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/game" <<'SH'
#!/bin/sh
echo "MockWindowGame (macOS mock)"
SH
chmod +x "$APP/Contents/MacOS/game"

cat > "$APP/Contents/Resources/assets/config.json" <<'JSON'
{ "name": "mock-window-game", "mock": true }
JSON
printf 'mock texture data\n' > "$APP/Contents/Resources/assets/texture.bin"

echo "✓ generated $APP"
