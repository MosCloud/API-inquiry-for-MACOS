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

echo "== 1/2 tests"
if ! env -u DEVELOPER_DIR swift run --disable-sandbox APIInquiryCoreTestsRunner; then
    echo "error: the test suite failed (step 1/2). The app was not built." >&2
    exit 1
fi

echo "== 2/2 app build ($configuration)"
source "$ROOT_DIR/Scripts/lib/toolchain.sh"
ensure_xcode_toolchain

if ! swift build --build-system native --disable-sandbox -c "$configuration"; then
    cat >&2 <<'MESSAGE'
error: the app target failed to compile (step 2/2).
       The test runner does not compile APIInquiryApp, so an App-only error shows up
       here and nowhere else. Fix it before opening the PR.
MESSAGE
    exit 1
fi

echo "verify: OK (tests + $configuration app build)"
