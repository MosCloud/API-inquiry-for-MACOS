#!/usr/bin/env bash
set -euo pipefail

APP_NAME="API Inquiry.app"
INSTALL_DIR="${API_INQUIRY_INSTALL_DIR:-$HOME/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME"
EXECUTABLE_NAME="APIInquiry"
EXECUTABLE_PATH="$TARGET_APP/Contents/MacOS/$EXECUTABLE_NAME"

if [ ! -x "$EXECUTABLE_PATH" ]; then
    echo "Installed app executable not found at $EXECUTABLE_PATH" >&2
    echo "Run Scripts/install-mac-app.sh first." >&2
    exit 1
fi

if /usr/bin/pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
    /usr/bin/pkill -x "$EXECUTABLE_NAME"
    sleep 1
fi

/usr/bin/open "$TARGET_APP"
sleep 1

if ! /bin/ps -axo command= | /usr/bin/awk -v path="$EXECUTABLE_PATH" '$0 == path { found = 1 } END { exit found ? 0 : 1 }'; then
    echo "API Inquiry did not start from $EXECUTABLE_PATH" >&2
    exit 1
fi

echo "Started $TARGET_APP"
