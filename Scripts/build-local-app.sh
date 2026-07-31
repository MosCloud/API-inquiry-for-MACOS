#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT_DIR/Scripts/version.env"
APP_DIR="$ROOT_DIR/.build/APIInquiry.app"
ACTIVE_MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_SDK_PATH="${API_INQUIRY_APP_SDKROOT:-$ACTIVE_MACOS_SDK_PATH}"
STAGING_ROOT="$(mktemp -d /private/tmp/api-inquiry-local-app.XXXXXX)"
STAGED_APP_DIR="$STAGING_ROOT/APIInquiry.app"
WORKTREE_ID="$(
    printf '%s' "$ROOT_DIR" |
        shasum -a 256 |
        awk '{ print substr($1, 1, 12) }'
)"
RUNTIME_APP_ROOT="/private/tmp/api-inquiry-local-app-${UID}-${WORKTREE_ID}"
RUNTIME_APP_DIR="$RUNTIME_APP_ROOT/APIInquiry.app"
EXECUTABLE_NAME="APIInquiry"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CONTROLLED_RUNTIME_TARGET_PATTERN="^/private/tmp/api-inquiry-local-app-${UID}-[^/]+/APIInquiry\\.app$"

cleanup_staging() {
    rm -rf "$STAGING_ROOT"
}

trap cleanup_staging EXIT

validate_runtime_root() {
    local runtime_root="$1"

    if [ -L "$runtime_root" ]; then
        echo "Refusing symlink runtime root: $runtime_root" >&2
        exit 1
    fi
    if [ ! -d "$runtime_root" ]; then
        echo "Refusing non-directory runtime root: $runtime_root" >&2
        exit 1
    fi
    if [ "$(stat -f '%u' "$runtime_root")" != "$UID" ]; then
        echo "Refusing runtime root not owned by current user: $runtime_root" >&2
        exit 1
    fi
}

retire_current_app_entry() {
    if [ -L "$APP_DIR" ]; then
        local runtime_target
        local runtime_root
        runtime_target="$(readlink "$APP_DIR")"
        if ! [[ "$runtime_target" =~ $CONTROLLED_RUNTIME_TARGET_PATTERN ]]; then
            echo "Refusing uncontrolled development app symlink: $APP_DIR -> $runtime_target" >&2
            exit 1
        fi

        runtime_root="${runtime_target%/APIInquiry.app}"
        if [ -e "$runtime_root" ] || [ -L "$runtime_root" ]; then
            validate_runtime_root "$runtime_root"
            if [ -e "$runtime_target" ] || [ -L "$runtime_target" ]; then
                if [ -L "$runtime_target" ]; then
                    rm -f "$runtime_target"
                elif [ ! -d "$runtime_target" ]; then
                    echo "Refusing invalid runtime app target: $runtime_target" >&2
                    exit 1
                else
                    if [ -x "$LSREGISTER" ]; then
                        "$LSREGISTER" -u "$runtime_target" >/dev/null 2>&1 || true
                    fi
                    rm -rf "$runtime_target"
                fi
            fi
            rmdir "$runtime_root"
        fi
        rm -f "$APP_DIR"
    elif [ -d "$APP_DIR" ]; then
        if [ -x "$LSREGISTER" ]; then
            "$LSREGISTER" -u "$APP_DIR" >/dev/null 2>&1 || true
        fi
        rm -rf "$APP_DIR"
    elif [ -e "$APP_DIR" ]; then
        echo "Refusing unexpected local app entry: $APP_DIR" >&2
        exit 1
    fi
}

prepare_runtime_root() {
    if [ -e "$RUNTIME_APP_ROOT" ] || [ -L "$RUNTIME_APP_ROOT" ]; then
        validate_runtime_root "$RUNTIME_APP_ROOT"
    else
        mkdir -m 700 "$RUNTIME_APP_ROOT"
    fi

    chmod 700 "$RUNTIME_APP_ROOT"
    validate_runtime_root "$RUNTIME_APP_ROOT"
}

cd "$ROOT_DIR"

SDKROOT="$APP_SDK_PATH" swift Scripts/generate-app-icon.swift
SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --product APIInquiryApp

CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/debug/APIInquiryApp" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$ROOT_DIR/.build/debug/APIInquiry_APIInquiryApp.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    find "$RESOURCE_BUNDLE" -maxdepth 1 -type f \( -name "*.png" -o -name "*.icns" \) -exec cp {} "$RESOURCES_DIR/" \;
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>API Inquiry</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.api-inquiry.APIInquiry</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>API Inquiry</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"
chflags -R nohidden "$STAGED_APP_DIR"
xattr -cr "$STAGED_APP_DIR"
codesign --force --deep --sign - "$STAGED_APP_DIR"
codesign --verify --deep --strict "$STAGED_APP_DIR"

retire_current_app_entry
prepare_runtime_root
rm -rf "$RUNTIME_APP_DIR"
ditto "$STAGED_APP_DIR" "$RUNTIME_APP_DIR"
codesign --verify --deep --strict "$RUNTIME_APP_DIR"
ln -s "$RUNTIME_APP_DIR" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
