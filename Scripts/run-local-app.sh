#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="APIInquiry.app"
APP_DIR="$ROOT_DIR/.build/$APP_NAME"
EXECUTABLE_NAME="APIInquiry"

cd "$ROOT_DIR"

Scripts/build-local-app.sh

if /usr/bin/pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
    /usr/bin/pkill -x "$EXECUTABLE_NAME"
    sleep 1
fi

# LaunchServices hands the caller's environment to the app it starts. Tools that are
# themselves Electron-based (this harness, for one) export ELECTRON_RUN_AS_NODE=1, which
# makes any Electron app we later open — VS Code via "Open Config", for example — start
# in Node mode and exit immediately, with `NSWorkspace.open` still reporting success.
unset ELECTRON_RUN_AS_NODE NODE_OPTIONS

/usr/bin/open "$APP_DIR"
echo "Started $APP_DIR"
