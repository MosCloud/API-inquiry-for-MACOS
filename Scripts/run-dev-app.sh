#!/usr/bin/env bash
# Builds a side-by-side development copy and launches it without touching the running app.
#
# The bundle is named "Development under <checkout>" and lives under
# /private/tmp/api-inquiry-development-<uid>-<worktree-id>/, with its own executable
# name, so it can run next to the main copy and is easy to quit or grep for.
#
# `--fixtures <scenario>` starts the copy with in-memory credentials and scripted
# provider data, so state checks need no keychain authorization.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKTREE_ID="$(
    printf '%s' "$ROOT_DIR" |
        shasum -a 256 |
        awk '{ print substr($1, 1, 12) }'
)"
DEVELOPMENT_APP="/private/tmp/api-inquiry-development-${UID}-${WORKTREE_ID}/APIInquiryDevelopment.app"
MAIN_BUNDLE_ID="com.api-inquiry.APIInquiry"
DEVELOPMENT_BUNDLE_ID="com.api-inquiry.APIInquiry.development"
DEVELOPMENT_PREFERENCES="$HOME/Library/Preferences/$DEVELOPMENT_BUNDLE_ID.plist"

cd "$ROOT_DIR"

build_arguments=()
fixture_arguments=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --fixtures)
            if [ "$#" -lt 2 ]; then
                echo "error: --fixtures needs a scenario (stale, failed, loading, multi)" >&2
                exit 2
            fi
            fixture_arguments+=(--fixtures "$2")
            shift 2
            ;;
        --fixtures=*)
            fixture_arguments+=("$1")
            shift
            ;;
        *)
            build_arguments+=("$1")
            shift
            ;;
    esac
done

if [ "${#build_arguments[@]}" -gt 0 ]; then
    Scripts/build-local-app.sh --dev "${build_arguments[@]}"
else
    Scripts/build-local-app.sh --dev
fi

if /usr/bin/pgrep -x APIInquiryDevelopment >/dev/null; then
    /usr/bin/pkill -x APIInquiryDevelopment
    sleep 1
fi

# The development copy keeps its own preferences domain so both menu bar items can
# coexist. Seed it once from the running app, then leave it alone.
if [ ! -f "$DEVELOPMENT_PREFERENCES" ]; then
    PREFERENCES_TMP="$(mktemp /tmp/api-inquiry-preferences.XXXXXX.plist)"
    if /usr/bin/defaults export "$MAIN_BUNDLE_ID" "$PREFERENCES_TMP" 2>/dev/null; then
        /usr/bin/defaults import "$DEVELOPMENT_BUNDLE_ID" "$PREFERENCES_TMP" 2>/dev/null || true
    fi
    rm -f "$PREFERENCES_TMP"
fi

# LaunchServices passes the caller's environment to the app; Electron-based tools
# export ELECTRON_RUN_AS_NODE, which breaks anything the app later opens with it.
unset ELECTRON_RUN_AS_NODE NODE_OPTIONS

if [ "${#fixture_arguments[@]}" -gt 0 ]; then
    /usr/bin/open -n "$DEVELOPMENT_APP" --args "${fixture_arguments[@]}"
    echo "Started development copy with fixtures: ${fixture_arguments[*]}"
else
    /usr/bin/open -n "$DEVELOPMENT_APP"
    echo "Started development copy: $DEVELOPMENT_APP"
fi
echo "Running app untouched. Quit the copy with: pkill -x APIInquiryDevelopment"
