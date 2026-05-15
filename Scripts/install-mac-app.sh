#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="API Inquiry.app"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
INSTALL_DIR="${API_INQUIRY_INSTALL_DIR:-$HOME/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/package-mac-app.sh"

if [ ! -d "$SOURCE_APP" ]; then
    echo "Package step did not create $SOURCE_APP" >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
xattr -cr "$TARGET_APP"
codesign --verify --deep "$TARGET_APP"

echo "Installed $TARGET_APP"
