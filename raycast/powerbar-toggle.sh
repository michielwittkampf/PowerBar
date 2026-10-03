#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle powerbar
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ⚡
# @raycast.packageName powerbar
# @raycast.description Toggle the menu bar power meter on/off

export PATH="$HOME/.homebrew/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
powerbar toggle
