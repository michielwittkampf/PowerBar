#!/bin/bash
# powerbar installer — works from a clone and via:
#   curl -fsSL https://raw.githubusercontent.com/michielwittkampf/powerbar/main/install.sh | bash
set -euo pipefail

REPO="${POWERBAR_REPO:-michielwittkampf/powerbar}"
BRANCH="${POWERBAR_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
CONFIG_DIR="$HOME/.config/powerbar"

say() { printf '→ %s\n' "$*"; }

command -v brew >/dev/null || { echo "Homebrew is missing — install it first: https://brew.sh"; exit 1; }
BREW_BIN="$(brew --prefix)/bin"

# Use files from the clone, otherwise fetch them from GitHub
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/powerbar.py" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
fetch() { # fetch <path-in-repo> <destination>
  if [ -n "$SRC" ]; then cp "$SRC/$1" "$2"; else curl -fsSL "$RAW/$1" -o "$2"; fi
}

say "macmon"
brew list macmon &>/dev/null || brew install macmon

say "SwiftBar"
[ -d /Applications/SwiftBar.app ] || brew install --cask swiftbar

# Respect an existing SwiftBar plugin folder, otherwise use ~/.swiftbar
PLUGINS="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
if [ -z "$PLUGINS" ]; then
  PLUGINS="$HOME/.swiftbar"
  defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGINS"
fi
PLUGINS="${PLUGINS/#\~/$HOME}"
mkdir -p "$PLUGINS"

# Clean up the old standalone version (power.py); the marker string is Dutch
# because it matches the text inside that old file
if [ -f "$PLUGINS/power.py" ] && grep -q "Systeemvermogen (rustig)" "$PLUGINS/power.py"; then
  say "removing old power.py"
  rm -f "$PLUGINS/power.py"
fi

say "plugin → $PLUGINS/powerbar.py"
fetch powerbar.py "$PLUGINS/powerbar.py"
chmod +x "$PLUGINS/powerbar.py"
xattr -c "$PLUGINS/powerbar.py" 2>/dev/null || true

say "command → $BREW_BIN/powerbar"
fetch bin/powerbar "$BREW_BIN/powerbar"
chmod +x "$BREW_BIN/powerbar"

if [ ! -f "$CONFIG_DIR/config" ]; then
  say "settings → $CONFIG_DIR/config"
  mkdir -p "$CONFIG_DIR"
  fetch config.example "$CONFIG_DIR/config"
fi

say "test: reading system power"
SAMPLE="$("$BREW_BIN/macmon" pipe -s 1 2>/dev/null | head -n 1 || true)"
printf '%s\n' "$SAMPLE" | /usr/bin/python3 -c '
import json, sys
d = json.loads(sys.stdin.readline())
sp = float(d.get("sys_power") or 0)
print("   sys_power = %.1f W" % sp if sp else "   note: sys_power is 0, plugin will only show chip power")
' 2>/dev/null || echo "   (test failed, continuing installation)"

say "(re)starting SwiftBar"
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -g -a SwiftBar
sleep 2
open -g "swiftbar://enableplugin?name=powerbar" 2>/dev/null || true

echo
echo "Done. Usage: powerbar on | off | toggle | status | config | update | uninstall"
echo "Tip: enable 'Launch at login' in SwiftBar's settings."
