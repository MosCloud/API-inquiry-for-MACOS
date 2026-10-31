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
test_timeout=600
build_timeout=1800

usage() {
    cat <<'USAGE'
usage: Scripts/verify.sh [--release] [--test-timeout SECONDS] [--build-timeout SECONDS]

  (no option)      tests + debug app build; the gate before opening a PR
  --release        tests + release app build; use before packaging
  --test-timeout   kill the test step after SECONDS (default 600)
  --build-timeout  kill the build step after SECONDS (default 1800)
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --release)
            configuration="release"
            ;;
        --test-timeout)
            if [ $# -lt 2 ]; then
                echo "error: --test-timeout needs a number of seconds" >&2
                exit 2
            fi
            test_timeout="$2"
            shift
            ;;
        --build-timeout)
            if [ $# -lt 2 ]; then
                echo "error: --build-timeout needs a number of seconds" >&2
                exit 2
            fi
            build_timeout="$2"
            shift
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

for value in "$test_timeout" "$build_timeout"; do
    case "$value" in
        '' | *[!0-9]*)
            echo "error: timeouts must be whole seconds, got '$value'" >&2
            exit 2
            ;;
    esac
done

# Runs a command under a deadline and turns a timeout into a readable failure.
#
# Why (#70): a gate that blocks forever is worse than one that fails. The test
# runner once sat in its run loop with no runnable task and `swift run` simply
# waited — the command looked like a slow build for 14 minutes and produced no
# output. `tail -3` on that pipeline shows nothing at all, which hides the bug.
# A deadline converts every such stall into a red gate that names the step.
run_with_deadline() {
    local deadline="$1"
    local label="$2"
    shift 2

    local rc=0
    timeout -k 10 "$deadline" "$@" || rc=$?

    case "$rc" in
        0)
            return 0
            ;;
        124 | 137)
            cat >&2 <<MESSAGE
error: $label did not finish within ${deadline}s and was terminated.
       A gate that hangs is worse than one that fails, so verify.sh turns the stall
       into this error instead of waiting forever. Re-run with a larger deadline
       (--test-timeout / --build-timeout) if the machine is merely slow; if it
       reproduces, a task is likely suspended on a signal that never arrives (#70).
MESSAGE
            return 1
            ;;
        *)
            return "$rc"
            ;;
    esac
}

total_start=$SECONDS

# Progress goes to stderr so a piped stdout (`| grep`, `| tail`) still shows it.
step_start=$SECONDS
echo "== 1/2 tests (timeout ${test_timeout}s; a cold build can take ~30s)" >&2
if ! run_with_deadline "$test_timeout" "the test suite" \
    env -u DEVELOPER_DIR swift run --disable-sandbox APIInquiryCoreTestsRunner; then
    echo "error: the test suite failed (step 1/2, $((SECONDS - step_start))s). The app was not built." >&2
    exit 1
fi
echo "== 1/2 tests: OK ($((SECONDS - step_start))s)" >&2

step_start=$SECONDS
echo "== 2/2 app build ($configuration, timeout ${build_timeout}s)" >&2
source "$ROOT_DIR/Scripts/lib/toolchain.sh"
ensure_xcode_toolchain

SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
modern_build_linker_args "$SDK_VERSION"

if ! run_with_deadline "$build_timeout" "the app build" \
    swift build --disable-sandbox -c "$configuration" "${MODERN_BUILD_LINKER_ARGS[@]}"; then
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
