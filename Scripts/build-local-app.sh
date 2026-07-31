#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/Scripts/version.env"
APP_DIR="$ROOT_DIR/.build/APIInquiry.app"
ACTIVE_MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_SDK_PATH="${API_INQUIRY_APP_SDKROOT:-$ACTIVE_MACOS_SDK_PATH}"
STAGING_ROOT="$(mktemp -d /private/tmp/api-inquiry-local-app.XXXXXX)"
STAGED_APP_DIR="$STAGING_ROOT/APIInquiry.app"
WORKTREE_NAME="$(basename "$ROOT_DIR")"
RUNTIME_APP_ROOT="/private/tmp/api-inquiry-local-app-${UID}-${WORKTREE_NAME}"
RUNTIME_APP_DIR="$RUNTIME_APP_ROOT/APIInquiry.app"
EXECUTABLE_NAME="APIInquiry"

cleanup_staging() {
    rm -rf "$STAGING_ROOT"
}

trap cleanup_staging EXIT

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

rm -rf "$RUNTIME_APP_DIR" "$APP_DIR"
mkdir -p "$RUNTIME_APP_ROOT"
ditto "$STAGED_APP_DIR" "$RUNTIME_APP_DIR"
codesign --verify --deep --strict "$RUNTIME_APP_DIR"
ln -s "$RUNTIME_APP_DIR" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
