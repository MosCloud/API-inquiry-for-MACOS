#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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
    if [ -d "$APP_PATH" ]; then
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
