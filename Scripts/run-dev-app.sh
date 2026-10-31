#!/usr/bin/env bash
# Builds a side-by-side development copy and launches it without touching the running app.
#
# The bundle is named "Development under <checkout>" and lives under
# /private/tmp/api-inquiry-development-<uid>-<worktree-id>/, with its own executable
# name, so it can run next to the main copy and is easy to quit or grep for.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKTREE_ID="$(
    printf '%s' "$ROOT_DIR" |
        shasum -a 256 |
        awk '{ print substr($1, 1, 12) }'
)"
DEVELOPMENT_APP="/private/tmp/api-inquiry-development-${UID}-${WORKTREE_ID}/APIInquiryDevelopment.app"

cd "$ROOT_DIR"
Scripts/build-local-app.sh --dev

if /usr/bin/pgrep -x APIInquiryDevelopment >/dev/null; then
    /usr/bin/pkill -x APIInquiryDevelopment
    sleep 1
fi

# LaunchServices passes the caller's environment to the app; Electron-based tools
# export ELECTRON_RUN_AS_NODE, which breaks anything the app later opens with it.
unset ELECTRON_RUN_AS_NODE NODE_OPTIONS

/usr/bin/open -n "$DEVELOPMENT_APP"
echo "Started development copy: $DEVELOPMENT_APP"
echo "Running app untouched. Quit the copy with: pkill -x APIInquiryDevelopment"
