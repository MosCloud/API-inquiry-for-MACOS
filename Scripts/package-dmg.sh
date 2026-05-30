#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Scripts/version.env"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="API Inquiry.app"
APP_DIR="$DIST_DIR/$APP_NAME"
DMG_NAME="$DMG_BASENAME.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
DMG_WORK_ROOT="${API_INQUIRY_DMG_WORK_ROOT:-/private/tmp/api-inquiry-dmg-$$}"
DMG_ROOT="$DMG_WORK_ROOT/dmg-root"
STAGING_MOUNT="$DMG_WORK_ROOT/dmg-staging-mount"
VERIFY_MOUNT="$DMG_WORK_ROOT/dmg-verify-mount"
RW_DMG_PATH="$DMG_WORK_ROOT/$DMG_BASENAME-rw.dmg"
DMG_BACKGROUND_PATH="$ROOT_DIR/Scripts/Assets/dmg-background.png"
DMG_SIZE="${API_INQUIRY_DMG_SIZE:-200m}"

detach_verify_mount() {
    hdiutil detach "$VERIFY_MOUNT" >/dev/null 2>&1 || true
}

detach_staging_mount() {
    hdiutil detach "$STAGING_MOUNT" >/dev/null 2>&1 || true
}

cleanup_dmg_work() {
    detach_staging_mount
    detach_verify_mount
    rm -rf "$DMG_WORK_ROOT"
}
trap cleanup_dmg_work EXIT

cd "$ROOT_DIR"

Scripts/package-mac-app.sh

rm -rf "$DMG_WORK_ROOT" "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$DMG_ROOT"

ditto "$APP_DIR" "$DMG_ROOT/$APP_NAME"
chflags -R nohidden "$DMG_ROOT/$APP_NAME"
xattr -cr "$DMG_ROOT/$APP_NAME"
ln -s /Applications "$DMG_ROOT/Applications"
if [ ! -f "$DMG_BACKGROUND_PATH" ]; then
    echo "DMG background is missing: $DMG_BACKGROUND_PATH" >&2
    exit 1
fi
mkdir -p "$DMG_ROOT/.background"
cp "$DMG_BACKGROUND_PATH" "$DMG_ROOT/.background/dmg-background.png"
chflags hidden "$DMG_ROOT/.background"

if ls -ldO "$DMG_ROOT/$APP_NAME" | grep -q hidden; then
    echo "$APP_NAME is hidden and would not appear in Finder." >&2
    exit 1
fi

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    -size "$DMG_SIZE" \
    "$RW_DMG_PATH"

detach_staging_mount
mkdir -p "$STAGING_MOUNT"
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$STAGING_MOUNT" "$RW_DMG_PATH" >/dev/null
if [ ! -d "$STAGING_MOUNT" ]; then
    echo "Mounted DMG volume is missing: $STAGING_MOUNT" >&2
    exit 1
fi

osascript <<APPLESCRIPT
with timeout of 20 seconds
    tell application "Finder"
        set stagingFolder to POSIX file "$STAGING_MOUNT" as alias
        open stagingFolder
        set stagingWindow to container window of stagingFolder
        set current view of stagingWindow to icon view
        try
            set toolbar visible of stagingWindow to false
        end try
        try
            set statusbar visible of stagingWindow to false
        end try
        set bounds of stagingWindow to {160, 160, 920, 580}
        set viewOptions to the icon view options of stagingWindow
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 152
        try
            set background picture of viewOptions to POSIX file "$STAGING_MOUNT/.background/dmg-background.png"
        end try
        set position of item "$APP_NAME" of stagingFolder to {210, 180}
        set position of item "Applications" of stagingFolder to {550, 180}
        delay 1
        close stagingWindow
    end tell
end timeout
APPLESCRIPT

sync
detach_staging_mount

hdiutil convert "$RW_DMG_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

hdiutil verify "$DMG_PATH"

mkdir -p "$VERIFY_MOUNT"
hdiutil attach -nobrowse -readonly -mountpoint "$VERIFY_MOUNT" "$DMG_PATH" >/dev/null

if [ ! -d "$VERIFY_MOUNT/$APP_NAME" ]; then
    echo "$APP_NAME is missing from $DMG_NAME." >&2
    exit 1
fi

if ls -ldO "$VERIFY_MOUNT/$APP_NAME" | grep -q hidden; then
    echo "$APP_NAME is hidden in $DMG_NAME and would not appear in Finder." >&2
    exit 1
fi

INFO_PLIST="$VERIFY_MOUNT/$APP_NAME/Contents/Info.plist"
EXECUTABLE_PATH="$VERIFY_MOUNT/$APP_NAME/Contents/MacOS/APIInquiry"

if [ ! -x "$EXECUTABLE_PATH" ]; then
    echo "Executable missing from $DMG_NAME." >&2
    exit 1
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$INFO_PLIST")
APP_VERSION_IN_PLIST=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
BUILD_NUMBER_IN_PLIST=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST")

if [ "$BUNDLE_ID" != "com.api-inquiry.APIInquiry" ]; then
    echo "Unexpected bundle id: $BUNDLE_ID" >&2
    exit 1
fi

if [ "$APP_VERSION_IN_PLIST" != "$APP_VERSION" ]; then
    echo "Unexpected app version: $APP_VERSION_IN_PLIST" >&2
    exit 1
fi

if [ "$BUILD_NUMBER_IN_PLIST" != "$BUILD_NUMBER" ]; then
    echo "Unexpected build number: $BUILD_NUMBER_IN_PLIST" >&2
    exit 1
fi

if [ ! -L "$VERIFY_MOUNT/Applications" ]; then
    echo "Applications shortcut is missing from $DMG_NAME." >&2
    exit 1
fi

detach_verify_mount
trap - EXIT
rm -rf "$DMG_WORK_ROOT"

(cd "$DIST_DIR" && /usr/bin/shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
(cd "$DIST_DIR" && /usr/bin/shasum -a 256 -c "$DMG_NAME.sha256")
echo "Checksum $CHECKSUM_PATH"
echo "Packaged $DMG_PATH"
