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

cleanup_staging() {
    rm -rf "$STAGING_ROOT"
}

trap cleanup_staging EXIT

cd "$ROOT_DIR"

swift Scripts/generate-app-icon.swift
swift build --configuration "$CONFIGURATION" --product "$PRODUCT_NAME"

rm -rf "$STAGING_ROOT" "$APP_DIR"
CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$ROOT_DIR/.build/$CONFIGURATION/$RESOURCE_BUNDLE_NAME"
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

mkdir -p "$DIST_DIR"
ditto "$STAGED_APP_DIR" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Packaged $APP_DIR"
