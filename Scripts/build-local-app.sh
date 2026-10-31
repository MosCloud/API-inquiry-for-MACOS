#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT_DIR/Scripts/version.env"
source "$ROOT_DIR/Scripts/lib/toolchain.sh"

BUILD_VARIANT="local"
ALLOW_DIRTY=0
for argument in "$@"; do
    case "$argument" in
        --dev)
            BUILD_VARIANT="dev"
            ;;
        --allow-dirty)
            ALLOW_DIRTY=1
            ;;
        -h|--help)
            cat <<'USAGE'
usage: Scripts/build-local-app.sh [--dev] [--allow-dirty]

  (no option)  dev bundle at .build/APIInquiry.app
  --dev        side-by-side development copy named after this checkout;
               never replaces the running app; refuses a dirty working tree
  --allow-dirty  with --dev, build even though the tree has uncommitted changes
USAGE
            exit 0
            ;;
        *)
            echo "error: unknown argument: $argument" >&2
            exit 2
            ;;
    esac
done

# The app cannot compile against Command Line Tools; pick Xcode unless the caller did.
# A copy used to verify a PR must correspond to a commit. Without this guard a
# dirty build silently tests something that is not in the branch.
if [ "$BUILD_VARIANT" = "dev" ] && [ "$ALLOW_DIRTY" != "1" ]; then
    if [ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)" ]; then
        cat >&2 <<'MESSAGE'
error: the working tree has uncommitted changes.
       A copy used to verify a PR has to match a commit: commit first, or pass
       --allow-dirty (the copy then carries the "+ 改动" marker).
MESSAGE
        exit 1
    fi
fi

ensure_xcode_toolchain

BUILD_ROOT="${API_INQUIRY_BUILD_ROOT:-$ROOT_DIR/.build}"
ACTIVE_MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_SDK_PATH="${API_INQUIRY_APP_SDKROOT:-$ACTIVE_MACOS_SDK_PATH}"
WORKTREE_ID="$(
    printf '%s' "$ROOT_DIR" |
        shasum -a 256 |
        awk '{ print substr($1, 1, 12) }'
)"
if [ "$BUILD_VARIANT" = "dev" ]; then
    CHECKOUT_NAME="$(basename "$ROOT_DIR")"
    APP_NAME="APIInquiryDevelopment.app"
    EXECUTABLE_NAME="APIInquiryDevelopment"
    DISPLAY_NAME="Development under $CHECKOUT_NAME"
    RUNTIME_APP_ROOT="/private/tmp/api-inquiry-development-${UID}-${WORKTREE_ID}"
    LINKS_APP_DIR=0
else
    APP_NAME="APIInquiry.app"
    EXECUTABLE_NAME="APIInquiry"
    DISPLAY_NAME="API Inquiry"
    RUNTIME_APP_ROOT="/private/tmp/api-inquiry-local-app-${UID}-${WORKTREE_ID}"
    LINKS_APP_DIR=1
fi
APP_DIR="$ROOT_DIR/.build/APIInquiry.app"
STAGING_ROOT="$(mktemp -d /private/tmp/api-inquiry-local-app.XXXXXX)"
STAGED_APP_DIR="$STAGING_ROOT/$APP_NAME"
RUNTIME_APP_DIR="$RUNTIME_APP_ROOT/$APP_NAME"
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
# Build with SwiftPM's native build system on purpose: the Xcode build system records
# LC_BUILD_VERSION sdk = the deployment target (13.0), which opts the app out of the
# macOS 26 design (legacy pop-up buttons, old panel chrome). The native build system
# records the real SDK. `assert_modern_build_sdk` below fails the build if that ever
# regresses, instead of shipping an app with the old chrome.
if [ "$BUILD_ROOT" = "$ROOT_DIR/.build" ]; then
    SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --build-system native --product APIInquiryApp
else
    # Scratch paths outside the checkout keep SwiftPM's bundle signing away from
    # Desktop/FileProvider metadata, which otherwise fails with "resource fork,
    # Finder information, or similar detritus".
    SDKROOT="$APP_SDK_PATH" swift build --sdk "$APP_SDK_PATH" --build-system native --scratch-path "$BUILD_ROOT" --product APIInquiryApp
fi

CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_ROOT/debug/APIInquiryApp" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
assert_modern_build_sdk "$MACOS_DIR/$EXECUTABLE_NAME"

RESOURCE_BUNDLE="$BUILD_ROOT/debug/APIInquiry_APIInquiryApp.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    # SwiftPM emits a flat bundle on its native build system but a macOS-style
    # bundle with Contents/Resources when it builds through the Xcode build
    # system, so search the whole bundle instead of only its top level.
    find "$RESOURCE_BUNDLE" -type f \( -name "*.png" -o -name "*.icns" -o -name "*.svg" \) -exec cp {} "$RESOURCES_DIR/" \;
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.api-inquiry.APIInquiry</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.0-dev</string>
    <key>CFBundleVersion</key>
    <string>0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Development builds carry no version number: the number lives only in release
# artifacts. Write the git commit instead so a local build can never pretend to be
# the released one, and so Finder/crash reports say "0.0.0-dev" rather than 0.3.16.
GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
GIT_DIRTY="false"
if [ -n "$GIT_COMMIT" ] && [ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)" ]; then
    GIT_DIRTY="true"
fi
if [ -n "$GIT_COMMIT" ]; then
    /usr/libexec/PlistBuddy -c "Delete :APIInquiryGitCommit" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Delete :APIInquiryGitDirty" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :APIInquiryGitCommit string $GIT_COMMIT" "$CONTENTS_DIR/Info.plist"
    if [ "$GIT_DIRTY" = "true" ]; then
        /usr/libexec/PlistBuddy -c "Add :APIInquiryGitDirty bool true" "$CONTENTS_DIR/Info.plist"
    fi
fi

plutil -lint "$CONTENTS_DIR/Info.plist"
chflags -R nohidden "$STAGED_APP_DIR"
xattr -cr "$STAGED_APP_DIR"
codesign --force --deep --sign - "$STAGED_APP_DIR"
codesign --verify --deep --strict "$STAGED_APP_DIR"

if [ "$LINKS_APP_DIR" = "1" ]; then
    retire_current_app_entry
fi

prepare_runtime_root
rm -rf "$RUNTIME_APP_DIR"
ditto "$STAGED_APP_DIR" "$RUNTIME_APP_DIR"
codesign --verify --deep --strict "$RUNTIME_APP_DIR"

if [ "$LINKS_APP_DIR" = "1" ]; then
    ln -s "$RUNTIME_APP_DIR" "$APP_DIR"
    codesign --verify --deep --strict "$APP_DIR"
fi

echo "app: $RUNTIME_APP_DIR"

if [ "$LINKS_APP_DIR" = "1" ]; then
    echo "Built $APP_DIR"
fi
