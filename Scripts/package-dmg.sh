#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0-alpha.1}"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="API Inquiry.app"
APP_DIR="$DIST_DIR/$APP_NAME"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_NAME="API-Inquiry-alpha.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="API Inquiry Alpha"

cd "$ROOT_DIR"

Scripts/package-mac-app.sh

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

ditto "$APP_DIR" "$DMG_ROOT/$APP_NAME"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
rm -rf "$DMG_ROOT"

echo "Packaged $DMG_PATH"
