#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Scripts/version.env"
source "$ROOT_DIR/Scripts/lib/toolchain.sh"

# The app cannot compile against Command Line Tools; pick Xcode unless the caller did.
ensure_xcode_toolchain

CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="API Inquiry.app"
APP_DIR="$DIST_DIR/$APP_NAME"
STAGING_ROOT="${API_INQUIRY_APP_PACKAGE_WORK_ROOT:-/private/tmp/api-inquiry-app-package-$$}"
STAGED_APP_DIR="$STAGING_ROOT/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_NAME="APIInquiry"
PRODUCT_NAME="APIInquiryApp"
RESOURCE_BUNDLE_NAME="APIInquiry_APIInquiryApp.bundle"
ACTIVE_MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_SDK_PATH="${API_INQUIRY_APP_SDKROOT:-$ACTIVE_MACOS_SDK_PATH}"

cleanup_staging() {
    rm -rf "$STAGING_ROOT"
}

trap cleanup_staging EXIT

cd "$ROOT_DIR"

if ! app_icon_is_current "$ROOT_DIR"; then
    SDKROOT="$APP_SDK_PATH" swift Scripts/generate-app-icon.swift
fi
# SwiftPM's default build system records LC_BUILD_VERSION sdk = the deployment target
# (13.0), which opts the app out of the macOS 26 design. Pass the real SDK version to
# the linker instead; `assert_modern_build_sdk` fails the build if that ever regresses.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
modern_build_linker_args "$SDK_VERSION"
SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --configuration "$CONFIGURATION" --product "$PRODUCT_NAME" "${MODERN_BUILD_LINKER_ARGS[@]}"
BIN_DIR="$(SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --configuration "$CONFIGURATION" --show-bin-path)"

rm -rf "$STAGING_ROOT" "$APP_DIR"
CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$PRODUCT_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
assert_modern_build_sdk "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$BIN_DIR/$RESOURCE_BUNDLE_NAME"
if [ -d "$RESOURCE_BUNDLE" ]; then
    # SwiftPM's default build system emits a macOS-style bundle with
    # Contents/Resources; search the whole bundle instead of only its top level.
    find "$RESOURCE_BUNDLE" -type f \( -name "*.png" -o -name "*.icns" -o -name "*.svg" \) -exec cp {} "$RESOURCES_DIR/" \;
fi

if [ ! -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    echo "AppIcon.icns was not copied into $RESOURCES_DIR; the resource bundle layout changed and the app would ship without an icon." >&2
    exit 1
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

# Release artifacts are the only place a version number lives. Strip the development
# markers a local build may have written, then prove the version matches version.env.
/usr/libexec/PlistBuddy -c "Delete :APIInquiryGitCommit" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :APIInquiryGitDirty" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true

packaged_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$CONTENTS_DIR/Info.plist")"
if [ "$packaged_version" != "$APP_VERSION" ]; then
    echo "refusing to package: bundle version '$packaged_version' != version.env '$APP_VERSION'" >&2
    exit 1
fi
if [ "$packaged_version" = "0.0.0-dev" ]; then
    echo "refusing to package a development build as a release" >&2
    exit 1
fi

plutil -lint "$CONTENTS_DIR/Info.plist"
chflags -R nohidden "$STAGED_APP_DIR"
xattr -cr "$STAGED_APP_DIR"
codesign --force --deep --sign - "$STAGED_APP_DIR"
codesign --verify --deep --strict "$STAGED_APP_DIR"

mkdir -p "$DIST_DIR"
ditto "$STAGED_APP_DIR" "$APP_DIR"
# On a Desktop/FileProvider path the copy can pick up Finder metadata shortly
# after it lands, which makes strict verification fail with "resource fork,
# Finder information, or similar detritus". Strip it before verifying; the DMG
# built from this copy is verified again after its own xattr cleanup.
# FileProvider can re-attach Finder metadata to a Desktop copy right after the
# strip, so verify with a couple of retries instead of failing the package run.
verified=0
for attempt in 1 2 3; do
    xattr -cr "$APP_DIR"
    if codesign --verify --deep --strict "$APP_DIR" 2>/dev/null; then
        verified=1
        break
    fi
    if [ "$attempt" -lt 3 ]; then
        sleep 0.5
    fi
done
if [ "$verified" != "1" ]; then
    echo "error: '$APP_DIR' still fails strict code-signature verification after stripping xattrs." >&2
    exit 1
fi

echo "Packaged $APP_DIR"
