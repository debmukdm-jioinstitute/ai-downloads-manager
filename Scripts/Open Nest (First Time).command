#!/bin/bash
# Double-click after dragging Nest to Applications.
set -e
APP="/Applications/Nest.app"
if [[ ! -d "$APP" ]]; then
  osascript -e 'display alert "Drag Nest to Applications first" message "Open the disk image, drag Nest into Applications, then run this script again." as warning'
  exit 1
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
open "$APP"
