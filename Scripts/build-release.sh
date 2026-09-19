#!/usr/bin/env bash
# Build Nest.app and Nest-*.dmg for Apple Silicon.
# For a build that opens without Gatekeeper warnings, set:
#   export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
#   export APPLE_ID="you@email.com"
#   export APPLE_ID_PASSWORD="@keychain:AC_PASSWORD"  # or app-specific password
#   export APPLE_TEAM_ID="TEAMID"
#   export NOTARIZE=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${NEST_VERSION:-1.0.1}"
BUILD_DIR="$ROOT/build/release"
APP_NAME="Nest"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"

echo "→ Building release binary (arm64)…"
swift build -c release --arch arm64

BIN="$(swift build -c release --arch arm64 --show-bin-path)/Nest"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN" "$APP_BUNDLE/Contents/MacOS/Nest"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

chmod +x "$APP_BUNDLE/Contents/MacOS/Nest"

if [[ -n "$IDENTITY" ]]; then
  echo "→ Signing with Developer ID…"
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/Resources/Entitlements.plist" \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"
else
  echo "→ Ad-hoc signing (Gatekeeper will warn until notarized)…"
  codesign --force --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict "$APP_BUNDLE"

if [[ "${NOTARIZE:-}" == "1" && -n "$IDENTITY" ]]; then
  echo "→ Notarizing…"
  ZIP="$BUILD_DIR/${APP_NAME}-notarize.zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"
  xcrun notarytool submit "$ZIP" --wait \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID"
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$ZIP"
fi

echo "→ Creating disk image…"
STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/Scripts/Open Nest (First Time).command" "$STAGE/"
cp "$ROOT/Scripts/DMG-README.txt" "$STAGE/READ ME FIRST.txt"

hdiutil create -volname "Nest" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGE"

if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" "$DMG_PATH" 2>/dev/null || true
fi

echo ""
echo "Done: $DMG_PATH"
if [[ -z "$IDENTITY" ]]; then
  echo "Note: Upload a notarized build for downloads that open without macOS security warnings."
fi
