# Current Task Plan

## Goal

Release `v0.3.8` as a focused OpenAI/Codex quota refresh stability fix from `main`.

## Current Status

- [x] Create isolated worktree branch `v0.3.8` from `main`.
- [x] Reproduce and diagnose the OpenAI/Codex quota mismatch and missing 7-day window.
- [x] Use multiple agents to review the fix boundary, regression coverage, and code quality.
- [x] Add regression tests for incomplete OpenAI/Codex quota responses and fractional quota percentages.
- [x] Fix `CodexQuotaProvider` so incomplete quota responses are retried once and never replace complete snapshots as successful data.
- [x] Verify the fix with `git diff --check`, `swift run APIInquiryCoreTestsRunner`, and `swift build`.
- [x] Commit the implementation fix as `fa49838`.
- [x] Update v0.3.8 release metadata, Settings version display, README, roadmap, and release notes.
- [x] Verify the release candidate with tests, build, local app launch, DMG packaging, Info.plist version checks, codesign verification, DMG verification, and checksum verification.
- [ ] Commit release metadata and documentation.
- [ ] Push `v0.3.8`, create tag `release/v0.3.8`, upload DMG assets, and publish the GitHub Release.

## Decisions

- `v0.3.8` is a bugfix release, not a provider expansion release.
- The fix belongs in `CodexQuotaProvider`; MenuBar and Console UI should continue rendering the provider snapshot they receive.
- OpenAI/Codex quota snapshots require both the 5-hour and 7-day windows. A response with only one window is treated as incomplete.
- Incomplete OpenAI/Codex quota responses are retried once. If the retry is still incomplete, the provider throws `missingBalanceInfo`, allowing `BalanceRefreshController` to preserve the last complete snapshot.
- `used_percent` is parsed as `Decimal` so fractional usage percentages are not truncated.
- `v0.4.0` remains the next planned provider expansion release.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| Sandbox blocked initial v0.3.8 branch creation | `git worktree add .worktrees/v0.3.8 -b v0.3.8 main` could not create a ref lock | Re-ran the same command with approved escalation and created the worktree successfully |
| SwiftPM/Clang cache write blocked in sandbox | `swift run APIInquiryCoreTestsRunner` and `swift build` without escalation could not write under `/Users/zbw/.cache/clang/ModuleCache` | Re-ran verification commands with approved escalation |
| First implementation pass had a Decimal migration compile error | `Decimal(window.usedPercent)` was left after changing `usedPercent` to `Decimal` | Removed the redundant initializer and re-ran tests successfully |

## Next Suggested Work

- Commit release docs/metadata, push branch and tag, upload DMG assets, and publish the GitHub Release.
