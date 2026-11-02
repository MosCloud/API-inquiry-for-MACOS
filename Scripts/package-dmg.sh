#!/usr/bin/env bash
#
# Builds the install window into a DMG. Two languages ship side by side, each
# with its own background picture, because one static PNG cannot follow the
# user's system language (#107).
#
#   Scripts/package-dmg.sh              # Chinese installer (default)
#   Scripts/package-dmg.sh --lang en    # English installer
#   Scripts/package-dmg.sh --all        # both, cross-checked against each other
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Scripts/version.env"
source "$ROOT_DIR/Scripts/dmg-layout.env"

DIST_DIR="$ROOT_DIR/dist"
APP_NAME="API Inquiry.app"
APP_DIR="$DIST_DIR/$APP_NAME"
ASSETS_DIR="$ROOT_DIR/Scripts/Assets"
BACKGROUND_GENERATOR="$ROOT_DIR/Scripts/generate-dmg-background.swift"
DMG_SIZE="${API_INQUIRY_DMG_SIZE:-200m}"

LANG_CODE=""
PACKAGE_ALL=0

usage() {
    cat <<'USAGE'
Usage: Scripts/package-dmg.sh [--lang zh|en] [--all]

  --lang zh   build the Chinese installer (default)
  --lang en   build the English installer
  --all       build both, then assert they carry the same app binary
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --lang)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            LANG_CODE="$2"
            shift 2
            ;;
        --lang=*)
            LANG_CODE="${1#*=}"
            shift
            ;;
        --all)
            PACKAGE_ALL=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$PACKAGE_ALL" -eq 1 ] && [ -n "$LANG_CODE" ]; then
    echo "--all already builds both languages; drop --lang." >&2
    exit 2
fi

if [ "$PACKAGE_ALL" -eq 0 ]; then
    LANG_CODE="${LANG_CODE:-zh}"
    case "$LANG_CODE" in
        zh|en) ;;
        *) echo "Unknown language: $LANG_CODE (expected zh or en)." >&2; exit 2 ;;
    esac
fi

# The window geometry lives in Scripts/dmg-layout.env because the generator and
# this script both need it; a second copy is how the arrow drifted 9.5 pt off
# the icon midpoint in the first place.
for layout_key in DMG_WINDOW_WIDTH DMG_WINDOW_HEIGHT DMG_WINDOW_LEFT DMG_WINDOW_TOP \
                  DMG_ICON_SIZE DMG_APP_ICON_X DMG_APP_ICON_Y DMG_FOLDER_ICON_X DMG_FOLDER_ICON_Y; do
    if [ -z "${!layout_key:-}" ]; then
        echo "Scripts/dmg-layout.env is missing $layout_key." >&2
        exit 1
    fi
done

WINDOW_LEFT="$DMG_WINDOW_LEFT"
WINDOW_TOP="$DMG_WINDOW_TOP"
WINDOW_RIGHT="$((DMG_WINDOW_LEFT + DMG_WINDOW_WIDTH))"
WINDOW_BOTTOM="$((DMG_WINDOW_TOP + DMG_WINDOW_HEIGHT))"

WORK_ROOTS=()

cleanup_work_roots() {
    for mount in "${MOUNTS[@]:-}"; do
        [ -n "$mount" ] && hdiutil detach "$mount" >/dev/null 2>&1 || true
    done
    for work_root in "${WORK_ROOTS[@]:-}"; do
        [ -n "$work_root" ] && rm -rf "$work_root" || true
    done
}
MOUNTS=()
trap cleanup_work_roots EXIT

executable_sha_in_dmg() {
    local mount="$1"
    /usr/bin/shasum -a 256 "$mount/$APP_NAME/Contents/MacOS/APIInquiry" | awk '{print $1}'
}

package_language() {
    local lang="$1"
    local dmg_basename dmg_name dmg_path checksum_path background_name
    case "$lang" in
        zh)
            dmg_basename="$DMG_BASENAME"
            background_name="dmg-background-zh.png"
            ;;
        en)
            if [ -z "${DMG_BASENAME_EN:-}" ]; then
                echo "Scripts/version.env is missing DMG_BASENAME_EN." >&2
                exit 1
            fi
            dmg_basename="$DMG_BASENAME_EN"
            background_name="dmg-background-en.png"
            ;;
    esac

    local background_path="$ASSETS_DIR/$background_name"
    if [ ! -f "$background_path" ]; then
        echo "DMG background is missing: $background_path" >&2
        exit 1
    fi

    dmg_name="$dmg_basename.dmg"
    dmg_path="$DIST_DIR/$dmg_name"
    checksum_path="$dmg_path.sha256"

    local work_root="${API_INQUIRY_DMG_WORK_ROOT:-/private/tmp/api-inquiry-dmg-$$}-$lang"
    local dmg_root="$work_root/dmg-root"
    local staging_mount="$work_root/dmg-staging-mount"
    local verify_mount="$work_root/dmg-verify-mount"
    local rw_dmg_path="$work_root/$dmg_basename-rw.dmg"

    WORK_ROOTS+=("$work_root")
    rm -rf "$work_root" "$dmg_path" "$checksum_path"
    mkdir -p "$dmg_root"

    ditto "$APP_DIR" "$dmg_root/$APP_NAME"
    chflags -R nohidden "$dmg_root/$APP_NAME"
    xattr -cr "$dmg_root/$APP_NAME"
    ln -s /Applications "$dmg_root/Applications"

    # The file name inside the volume stays dmg-background.png for both
    # languages: the layout assertions and the .DS_Store alias check key on it.
    mkdir -p "$dmg_root/.background"
    cp "$background_path" "$dmg_root/.background/dmg-background.png"
    chflags hidden "$dmg_root/.background"

    if ls -ldO "$dmg_root/$APP_NAME" | grep -q hidden; then
        echo "$APP_NAME is hidden and would not appear in Finder." >&2
        exit 1
    fi

    hdiutil create \
        -volname "$VOLUME_NAME" \
        -srcfolder "$dmg_root" \
        -ov \
        -fs HFS+ \
        -format UDRW \
        -size "$DMG_SIZE" \
        "$rw_dmg_path"

    mkdir -p "$staging_mount"
    hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$staging_mount" "$rw_dmg_path" >/dev/null
    MOUNTS+=("$staging_mount")
    if [ ! -d "$staging_mount" ]; then
        echo "Mounted DMG volume is missing: $staging_mount" >&2
        exit 1
    fi

    osascript <<APPLESCRIPT
with timeout of 30 seconds
    tell application "Finder"
        -- Finder only applies (and then persists) window view options while it is
        -- the frontmost app; scripting it from the background silently drops the
        -- background picture and icon positions.
        activate
        set stagingFolder to POSIX file "$staging_mount" as alias
        open stagingFolder
        delay 1
        set stagingWindow to container window of stagingFolder
        set current view of stagingWindow to icon view
        try
            set toolbar visible of stagingWindow to false
        end try
        try
            set statusbar visible of stagingWindow to false
        end try
        set bounds of stagingWindow to {$WINDOW_LEFT, $WINDOW_TOP, $WINDOW_RIGHT, $WINDOW_BOTTOM}
        set viewOptions to the icon view options of stagingWindow
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $DMG_ICON_SIZE
        set background picture of viewOptions to POSIX file "$staging_mount/.background/dmg-background.png"
        set position of item "$APP_NAME" of stagingFolder to {$DMG_APP_ICON_X, $DMG_APP_ICON_Y}
        set position of item "Applications" of stagingFolder to {$DMG_FOLDER_ICON_X, $DMG_FOLDER_ICON_Y}
        update stagingFolder
    end tell
end timeout
APPLESCRIPT

    # Finder only flushes the view options to .DS_Store while the window is still
    # open: polling for the background alias before closing the window keeps a
    # detached volume from ending up as a .DS_Store stub, which would ship a DMG
    # with no background picture and Finder's default icon arrangement.
    local layout_persisted=0
    for _ in $(seq 1 40); do
        if strings -a "$staging_mount/.DS_Store" 2>/dev/null | grep -q "dmg-background.png"; then
            layout_persisted=1
            break
        fi
        sleep 0.25
    done

    if [ "$layout_persisted" -ne 1 ]; then
        echo "Finder did not persist the DMG window layout on $staging_mount." >&2
        exit 1
    fi

    osascript <<APPLESCRIPT
with timeout of 20 seconds
    tell application "Finder"
        try
            close container window of (POSIX file "$staging_mount" as alias)
        end try
    end tell
end timeout
APPLESCRIPT

    sync
    hdiutil detach "$staging_mount" >/dev/null 2>&1 || true
    MOUNTS=("${MOUNTS[@]/$staging_mount/}")

    hdiutil convert "$rw_dmg_path" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$dmg_path"

    hdiutil verify "$dmg_path"

    mkdir -p "$verify_mount"
    hdiutil attach -nobrowse -readonly -mountpoint "$verify_mount" "$dmg_path" >/dev/null
    MOUNTS+=("$verify_mount")

    if [ ! -d "$verify_mount/$APP_NAME" ]; then
        echo "$APP_NAME is missing from $dmg_name." >&2
        exit 1
    fi

    if ls -ldO "$verify_mount/$APP_NAME" | grep -q hidden; then
        echo "$APP_NAME is hidden in $dmg_name and would not appear in Finder." >&2
        exit 1
    fi

    local info_plist="$verify_mount/$APP_NAME/Contents/Info.plist"
    local executable_path="$verify_mount/$APP_NAME/Contents/MacOS/APIInquiry"

    if [ ! -x "$executable_path" ]; then
        echo "Executable missing from $dmg_name." >&2
        exit 1
    fi

    local bundle_id app_version_in_plist build_number_in_plist
    bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$info_plist")
    app_version_in_plist=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$info_plist")
    build_number_in_plist=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$info_plist")

    if [ "$bundle_id" != "com.api-inquiry.APIInquiry" ]; then
        echo "Unexpected bundle id: $bundle_id" >&2
        exit 1
    fi

    if [ "$app_version_in_plist" != "$APP_VERSION" ]; then
        echo "Unexpected app version: $app_version_in_plist" >&2
        exit 1
    fi

    if [ "$build_number_in_plist" != "$BUILD_NUMBER" ]; then
        echo "Unexpected build number: $build_number_in_plist" >&2
        exit 1
    fi

    if [ ! -L "$verify_mount/Applications" ]; then
        echo "Applications shortcut is missing from $dmg_name." >&2
        exit 1
    fi

    if [ ! -f "$verify_mount/.DS_Store" ] ||
       ! strings -a "$verify_mount/.DS_Store" | grep -q "dmg-background.png"; then
        echo "Window layout is missing from $dmg_name: Finder never applied the background and icon positions." >&2
        exit 1
    fi

    PACKAGED_EXEC_SHA="$(executable_sha_in_dmg "$verify_mount")"

    hdiutil detach "$verify_mount" >/dev/null 2>&1 || true
    MOUNTS=("${MOUNTS[@]/$verify_mount/}")
    rm -rf "$work_root"
    WORK_ROOTS=("${WORK_ROOTS[@]/$work_root}")

    (cd "$DIST_DIR" && /usr/bin/shasum -a 256 "$dmg_name" > "$dmg_name.sha256")
    (cd "$DIST_DIR" && /usr/bin/shasum -a 256 -c "$dmg_name.sha256")
    echo "Packaged $dmg_path"
}

cd "$ROOT_DIR"

Scripts/package-mac-app.sh

if [ ! -f "$BACKGROUND_GENERATOR" ]; then
    echo "DMG background generator is missing: $BACKGROUND_GENERATOR" >&2
    exit 1
fi
# Render from source every time: the headline carries the version number, so a
# stale picture would ship last release's stamp.
swift "$BACKGROUND_GENERATOR"

if [ "$PACKAGE_ALL" -eq 1 ]; then
    package_language zh
    SHA_ZH="$PACKAGED_EXEC_SHA"
    package_language en
    SHA_EN="$PACKAGED_EXEC_SHA"

    if [ "$SHA_ZH" != "$SHA_EN" ]; then
        echo "The two DMGs carry different app binaries ($SHA_ZH vs $SHA_EN); they must be one build." >&2
        exit 1
    fi
    echo "Both installers carry the same app binary: $SHA_ZH"
    echo "Packaged $DIST_DIR/$DMG_BASENAME.dmg and $DIST_DIR/${DMG_BASENAME_EN}.dmg"
else
    package_language "$LANG_CODE"
fi

trap - EXIT
cleanup_work_roots
