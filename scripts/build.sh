#!/bin/bash
# Build PowerBar.app from the Swift package (release build, ad-hoc signed).
# Usage: scripts/build.sh [--install]   (--install copies it to ~/Applications and opens it)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="0.5.0"
APP="$ROOT/build/PowerBar.app"

# Build identity. CFBundleVersion must be numeric, so it gets the commit count;
# About shows the short commit hash (+ when built with uncommitted changes).
BUILD="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 0)"
COMMIT="$(git -C "$ROOT" rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
git -C "$ROOT" diff --quiet HEAD 2>/dev/null || COMMIT="$COMMIT+"

swift build --package-path "$ROOT" -c release
BIN="$(swift build --package-path "$ROOT" -c release --show-bin-path)/PowerBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PowerBar"
cp "$ROOT/Resources/config.example" "$APP/Contents/Resources/config.example"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"  # made by make-icon.swift

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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>PowerBarCommit</key><string>$COMMIT</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© Michiel Wittkampf · MIT License</string>
</dict>
</plist>
EOF

# Ad-hoc signature with the hardened runtime. There is no Developer ID, so
# Gatekeeper stops a downloaded copy on first launch (see README).
codesign --force --options runtime --sign - "$APP"
echo "Built $APP ($VERSION, build $BUILD, $COMMIT)"

if [ "${1:-}" = "--install" ]; then
  pkill -x PowerBar 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/PowerBar.app"
  cp -R "$APP" "$HOME/Applications/"
  open "$HOME/Applications/PowerBar.app"
  echo "Installed and started ~/Applications/PowerBar.app"
fi
