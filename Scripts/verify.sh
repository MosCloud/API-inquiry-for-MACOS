#!/usr/bin/env bash
# The PR gate: run the test suite and compile every target, including APIInquiryApp.
#
# Why a script: the test runner never compiles APIInquiryApp, so a missing switch
# case or a SwiftUI-only error passes `swift run APIInquiryCoreTestsRunner` and
# only fails the app build. Running both steps here in one command makes that
# gap hard to skip.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

configuration="debug"

usage() {
    cat <<'USAGE'
usage: Scripts/verify.sh [--release]

  (no option)  tests + debug app build; the gate before opening a PR
  --release    tests + release app build; use before packaging
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --release)
            configuration="release"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

total_start=$SECONDS

# Progress goes to stderr so a piped stdout (`| grep`, `| tail`) still shows it.
step_start=$SECONDS
echo "== 1/2 tests (a cold build can take ~30s)" >&2
if ! env -u DEVELOPER_DIR swift run --disable-sandbox APIInquiryCoreTestsRunner; then
    echo "error: the test suite failed (step 1/2, $((SECONDS - step_start))s). The app was not built." >&2
    exit 1
fi
echo "== 1/2 tests: OK ($((SECONDS - step_start))s)" >&2

step_start=$SECONDS
echo "== 2/2 app build ($configuration)" >&2
source "$ROOT_DIR/Scripts/lib/toolchain.sh"
ensure_xcode_toolchain

SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
modern_build_linker_args "$SDK_VERSION"

if ! swift build --disable-sandbox -c "$configuration" "${MODERN_BUILD_LINKER_ARGS[@]}"; then
    echo "error: the app target failed to compile (step 2/2, $((SECONDS - step_start))s)." >&2
    cat >&2 <<'MESSAGE'
       The test runner does not compile APIInquiryApp, so an App-only error shows up
       here and nowhere else. Fix it before opening the PR.
MESSAGE
    exit 1
fi

BIN_DIR="$(swift build --disable-sandbox -c "$configuration" --show-bin-path)"
assert_modern_build_sdk "$BIN_DIR/APIInquiryApp"

echo "== 2/2 app build: OK ($((SECONDS - step_start))s)" >&2
echo "verify: OK (tests + $configuration app build) in $((SECONDS - total_start))s"
