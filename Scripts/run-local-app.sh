#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="API Inquiry.app"
APP_DIR="$ROOT_DIR/.build/$APP_NAME"
EXECUTABLE_NAME="APIInquiry"

cd "$ROOT_DIR"

Scripts/build-local-app.sh

if /usr/bin/pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
    /usr/bin/pkill -x "$EXECUTABLE_NAME"
    sleep 1
fi

/usr/bin/open "$APP_DIR"
echo "Started $APP_DIR"
