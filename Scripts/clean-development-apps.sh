#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CONTROLLED_RUNTIME_TARGET_PATTERN="^/private/tmp/api-inquiry-local-app-${UID}-[^/]+/APIInquiry\\.app$"

shopt -s nullglob

APP_PATHS=(
    "$ROOT_DIR/.build/APIInquiry.app"
    "$ROOT_DIR/dist/API Inquiry.app"
    "$ROOT_DIR/dist/dmg-root/API Inquiry.app"
    "$ROOT_DIR"/.worktrees/*/.build/APIInquiry.app
    "$ROOT_DIR"/.worktrees/*/dist/API\ Inquiry.app
    "$ROOT_DIR"/.worktrees/*/dist/dmg-root/API\ Inquiry.app
)

FOUND=0
for APP_PATH in "${APP_PATHS[@]}"; do
    if [ -L "$APP_PATH" ]; then
        FOUND=1
        RUNTIME_TARGET="$(readlink "$APP_PATH")"
        if ! [[ "$RUNTIME_TARGET" =~ $CONTROLLED_RUNTIME_TARGET_PATTERN ]]; then
            echo "Refusing uncontrolled development app symlink: $APP_PATH -> $RUNTIME_TARGET" >&2
            exit 1
        fi

        RUNTIME_ROOT="${RUNTIME_TARGET%/APIInquiry.app}"
        if [ -e "$RUNTIME_ROOT" ] || [ -L "$RUNTIME_ROOT" ]; then
            if [ -L "$RUNTIME_ROOT" ] || [ ! -d "$RUNTIME_ROOT" ]; then
                echo "Refusing invalid runtime root: $RUNTIME_ROOT" >&2
                exit 1
            fi
            if [ "$(stat -f '%u' "$RUNTIME_ROOT")" != "$UID" ]; then
                echo "Refusing runtime root not owned by current user: $RUNTIME_ROOT" >&2
                exit 1
            fi
            if [ -e "$RUNTIME_TARGET" ] || [ -L "$RUNTIME_TARGET" ]; then
                if [ -L "$RUNTIME_TARGET" ]; then
                    rm -f "$RUNTIME_TARGET"
                elif [ ! -d "$RUNTIME_TARGET" ]; then
                    echo "Refusing invalid runtime app target: $RUNTIME_TARGET" >&2
                    exit 1
                else
                    if [ -x "$LSREGISTER" ]; then
                        "$LSREGISTER" -u "$RUNTIME_TARGET" >/dev/null 2>&1 || true
                    fi
                    rm -rf "$RUNTIME_TARGET"
                fi
            fi
            rmdir "$RUNTIME_ROOT"
        fi
        rm -f "$APP_PATH"
        echo "Removed $APP_PATH"
    elif [ -d "$APP_PATH" ]; then
        FOUND=1
        if [ -x "$LSREGISTER" ]; then
            "$LSREGISTER" -u "$APP_PATH" >/dev/null 2>&1 || true
        fi
        rm -rf "$APP_PATH"
        echo "Removed $APP_PATH"
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo "No development app bundles found."
fi
