# Current Progress

## 2026-06-03

- Investigated a reported mismatch between official Codex/OpenAI quota display and API Inquiry v0.3.7.
- Confirmed that an incomplete OpenAI/Codex usage response could contain only the 5-hour window, causing API Inquiry to show `5h 100%` and hide the 7-day quota row.
- Created isolated worktree branch `v0.3.8` from `main`.
- Used multiple agents:
  - one explorer for implementation boundary review
  - one explorer for regression test design
  - one read-only code reviewer for the final implementation diff
- Added failing regression tests for:
  - incomplete quota response retry
  - missing secondary quota window retry
  - repeated incomplete responses mapping to `missingBalanceInfo`
  - fractional and quoted numeric `used_percent` parsing
  - preserving the last complete quota snapshot after repeated incomplete refreshes
- Implemented the provider-layer fix in `CodexQuotaProvider`.
- Verified the implementation with:
  - `git diff --check`
  - `swift run APIInquiryCoreTestsRunner` (`PASS: 524 expectations`)
  - `swift build`
- Launched the local v0.3.8 app for user validation with `Scripts/run-local-app.sh`.
- Committed the implementation fix:
  - `fa49838 fix: stabilize codex quota refresh`
- Prepared v0.3.8 release metadata and documentation:
  - `Scripts/version.env` now points to app version `0.3.8`, build `13`, tag `release/v0.3.8`, and `API-Inquiry-v0.3.8` DMG naming
  - Settings version display now uses `v0.3.8`
  - README, README_zh, README_en, and roadmap now identify `v0.3.8` as the latest release
  - added `docs/releases/v0.3.8.md`, `docs/releases/v0.3.8_zh.md`, and `docs/releases/v0.3.8_github.md`
- Verified the v0.3.8 release candidate with:
  - `git diff --check`
  - `swift run APIInquiryCoreTestsRunner` (`PASS: 524 expectations`)
  - `swift build`
  - `Scripts/run-local-app.sh`, which started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.8/.build/APIInquiry.app`
  - `Scripts/package-dmg.sh`, which produced `dist/API-Inquiry-v0.3.8.dmg` and `dist/API-Inquiry-v0.3.8.dmg.sha256`
  - `CFBundleShortVersionString` = `0.3.8`
  - `CFBundleVersion` = `13`
  - `codesign --verify --deep "dist/API Inquiry.app"`
  - `hdiutil verify dist/API-Inquiry-v0.3.8.dmg`
  - `(cd dist && shasum -a 256 -c API-Inquiry-v0.3.8.dmg.sha256)`
  - DMG SHA-256: `1b7208e286fe93a096be17443c046aa1c3f899c01d51aa8db3734d588b18a307`

## Current State

- Active worktree branch for the current task is `v0.3.8`.
- `v0.3.8` was created from `main` commit `33467a6`.
- Implementation fix is committed as `fa49838`.
- Release metadata/documentation updates and local release candidate verification are complete; commit, tag, push, and GitHub Release publication remain.

## Open Notes

- The main worktree `.superpowers/` directory remains untracked and has not been modified.
- Apple notarization remains out of scope.
