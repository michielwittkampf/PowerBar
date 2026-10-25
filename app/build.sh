#!/bin/bash
# Build PowerBar.app from the Swift package (release build, ad-hoc signed).
# Usage: app/build.sh [--install]   (--install copies it to ~/Applications and opens it)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="0.1.0"
APP="$HERE/build/PowerBar.app"

swift build --package-path "$HERE" -c release
BIN="$(swift build --package-path "$HERE" -c release --show-bin-path)/PowerBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PowerBar"
cp "$HERE/../config.example" "$APP/Contents/Resources/config.example"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PowerBar</string>
  <key>CFBundleDisplayName</key><string>PowerBar</string>
  <key>CFBundleIdentifier</key><string>nl.michielwittkampf.powerbar</string>
  <key>CFBundleExecutable</key><string>PowerBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x PowerBar 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/PowerBar.app"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/PowerBar.app"
  echo "Installed and started ~/Applications/PowerBar.app"
fi
