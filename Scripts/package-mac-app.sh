#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Scripts/version.env"
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

SDKROOT="$APP_SDK_PATH" swift Scripts/generate-app-icon.swift
# Build with SwiftPM's native build system on purpose: the Xcode build system records
# LC_BUILD_VERSION sdk = the deployment target (13.0), which opts the app out of the
# macOS 26 design (legacy pop-up buttons, old panel chrome). The native build system
# records the real SDK, matching v0.3.15. Verify with:
#   otool -l "<app>/Contents/MacOS/APIInquiry" | grep -A4 LC_BUILD_VERSION
SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --build-system native --configuration "$CONFIGURATION" --product "$PRODUCT_NAME"

rm -rf "$STAGING_ROOT" "$APP_DIR"
CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$ROOT_DIR/.build/$CONFIGURATION/$RESOURCE_BUNDLE_NAME"
if [ -d "$RESOURCE_BUNDLE" ]; then
    # SwiftPM writes a flat bundle on its native build system but a macOS-style
    # bundle with Contents/Resources when it builds through the Xcode build
    # system, so search the whole bundle instead of only its top level.
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
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Packaged $APP_DIR"
