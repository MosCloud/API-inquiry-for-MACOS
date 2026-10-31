#!/usr/bin/env bash
# Shared build-environment guards for the app scripts.
#
# Why this exists: `xcode-select` on this machine points at Command Line Tools,
# whose SDK cannot resolve the SwiftUI macros, so anything that compiles
# `APIInquiryApp` fails unless the Xcode toolchain is selected. And SwiftPM's
# default (Xcode) build system records `LC_BUILD_VERSION sdk` as the deployment
# target (13.0), which silently opts the app out of the macOS 26 design. Both
# failure modes are cheap to detect up front and expensive to notice later, so
# the two app scripts call the guards here instead of repeating them.

# Select Xcode's developer directory when the caller has not chosen one.
# An explicit DEVELOPER_DIR always wins; the current toolchain is accepted when
# it already is an Xcode one.
ensure_xcode_toolchain() {
    if [ -n "${DEVELOPER_DIR:-}" ]; then
        return 0
    fi

    if [ -d /Applications/Xcode.app/Contents/Developer ]; then
        export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
        return 0
    fi

    case "$(xcode-select -p 2>/dev/null || true)" in
        */Xcode*.app/Contents/Developer) return 0 ;;
    esac

    cat >&2 <<'MESSAGE'
error: APIInquiryApp needs Xcode's toolchain; Command Line Tools cannot resolve the SwiftUI macros.
       Install Xcode at /Applications/Xcode.app, or export DEVELOPER_DIR to an Xcode developer directory.
       Core-only work (tests, docs) still runs without Xcode: swift run APIInquiryCoreTestsRunner
MESSAGE
    exit 1
}

# SwiftPM's default build system records LC_BUILD_VERSION sdk as the deployment
# target, which opts the app out of the current macOS design. Passing the real SDK
# version to the linker restores it without the deprecated `--build-system native`.
# Usage: modern_build_linker_args "$SDK_VERSION"; swift build ... "${MODERN_BUILD_LINKER_ARGS[@]}"
readonly API_INQUIRY_MINIMUM_MACOS="13.0"

modern_build_linker_args() {
    local sdk_version="$1"

    if [ -z "$sdk_version" ]; then
        echo "error: missing macOS SDK version for the linker override." >&2
        exit 1
    fi

    MODERN_BUILD_LINKER_ARGS=(
        -Xlinker -platform_version
        -Xlinker macos
        -Xlinker "$API_INQUIRY_MINIMUM_MACOS"
        -Xlinker "$sdk_version"
    )
}

# The minimum SDK major version that still opts into the current macOS design.
# The Xcode build system records the deployment target (13.0) here instead.
readonly API_INQUIRY_MINIMUM_BUILD_SDK_MAJOR=20

# Fail when `binary` links against a deployment-target SDK rather than a real one.
assert_modern_build_sdk() {
    local binary="$1"
    local sdk major

    if [ ! -f "$binary" ]; then
        echo "error: cannot verify the build SDK: '$binary' does not exist." >&2
        exit 1
    fi

    sdk="$(
        otool -l "$binary" | awk '
            /LC_BUILD_VERSION/ { found = 1; next }
            found && $1 == "sdk" { print $2; exit }
        '
    )"

    case "$sdk" in
        "" | *[!0-9.]*)
            echo "error: no readable LC_BUILD_VERSION sdk in '$binary'; cannot prove the build uses a real SDK." >&2
            exit 1
            ;;
    esac

    major="${sdk%%.*}"
    if [ "$major" -lt "$API_INQUIRY_MINIMUM_BUILD_SDK_MAJOR" ]; then
        cat >&2 <<MESSAGE
error: '$binary' was linked against sdk $sdk, which is the deployment target rather than a real SDK.
       That build opts the app out of the macOS 26 design (legacy panel chrome, wide pop-up buttons).
       Rebuild with the app scripts; they pass the real SDK version to the linker.
MESSAGE
        exit 1
    fi
}

# Regenerating the icon costs a couple of seconds per build; skip it when the
# generated files are newer than both their source image and the generator.
app_icon_is_current() {
    local root="$1"
    local source="$root/Scripts/Assets/deepseek-app-symbol-source.png"
    local generator="$root/Scripts/generate-app-icon.swift"
    local icns="$root/Sources/APIInquiryApp/Resources/AppIcon.icns"
    local preview="$root/Sources/APIInquiryApp/Resources/AppIcon.png"

    [ -f "$source" ] || return 1
    [ -f "$icns" ] || return 1
    [ -f "$preview" ] || return 1

    [ "$icns" -nt "$source" ] || return 1
    [ "$icns" -nt "$generator" ] || return 1
    [ "$preview" -nt "$source" ] || return 1
    [ "$preview" -nt "$generator" ]
}
