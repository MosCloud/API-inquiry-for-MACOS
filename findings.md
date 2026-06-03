# Current Findings

## Repository State

- Current branch/worktree: `v0.3.8` at `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.8`.
- Branch base: current `main` commit `33467a6` (`docs: make v0.3.7 release notes user-facing`).
- `v0.3.8` is a focused bugfix release for OpenAI/Codex quota refresh stability.
- The main worktree still has an untracked `.superpowers/` directory that should not be touched unless explicitly requested.

## Root Cause

- OpenAI/Codex usage responses can be incomplete under some network/proxy conditions, for example returning only `rate_limit.primary_window` while `secondary_window` is `null` or missing.
- API Inquiry v0.3.7 accepted any non-empty quota window list as a successful `QuotaUsageSnapshot`.
- That allowed a partial response such as `primary_window.used_percent = 0` and no 7-day window to replace a complete snapshot, causing the menu to show `5h 100%` and hide the 7-day quota row.
- The UI was not hiding the 7-day row; it rendered the windows provided by the provider.

## Fix Findings

- `CodexQuotaProvider` now requires both primary and secondary quota windows before emitting a new snapshot.
- `CodexQuotaProvider` retries once when decoding yields `missingBalanceInfo`; this covers short-lived incomplete usage responses.
- If the retry is still incomplete, `missingBalanceInfo` propagates and `BalanceRefreshController` preserves the last complete snapshot as designed.
- `used_percent` is now parsed as `Decimal`, including fractional numbers and quoted numeric strings, so the app avoids integer truncation drift from the official Codex display.
- No menu bar or Console layout changes were needed.

## Review Findings

- Explorer review confirmed the fix belongs in `CodexQuotaProvider`, not in `BalanceRefreshController`, ViewModels, or SwiftUI views.
- Test-design review recommended coverage for null/missing secondary windows, Decimal percentage parsing, and controller preservation of complete snapshots; these were added.
- Code-quality review found no Critical, Important, or Minor issues in the uncommitted implementation diff.

## Important Files

- Implementation:
  - `Sources/APIInquiryCore/Providers/CodexQuotaProvider.swift`
- Regression tests:
  - `Sources/APIInquiryCoreTestsRunner/CodexQuotaProviderTests.swift`
  - `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`
- Release metadata/docs:
  - `Scripts/version.env`
  - `Sources/APIInquiryApp/AppVersion.swift`
  - `README.md`
  - `README_zh.md`
  - `README_en.md`
  - `docs/roadmap.md`
  - `docs/releases/v0.3.8.md`
  - `docs/releases/v0.3.8_zh.md`
  - `docs/releases/v0.3.8_github.md`

## Verification Evidence

- During implementation:
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 524 expectations`.
  - `swift build` passed.
  - `git diff --check` passed.
  - `Scripts/run-local-app.sh` built and started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.8/.build/APIInquiry.app` for manual validation.
- During v0.3.8 release candidate verification:
  - `git diff --check` passed.
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 524 expectations`.
  - `swift build` passed.
  - `Scripts/run-local-app.sh` built and started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.8/.build/APIInquiry.app`.
  - `Scripts/package-dmg.sh` produced `dist/API-Inquiry-v0.3.8.dmg` and `dist/API-Inquiry-v0.3.8.dmg.sha256`.
  - `CFBundleShortVersionString` is `0.3.8`.
  - `CFBundleVersion` is `13`.
  - `codesign --verify --deep "dist/API Inquiry.app"` passed.
  - `hdiutil verify dist/API-Inquiry-v0.3.8.dmg` passed.
  - `(cd dist && shasum -a 256 -c API-Inquiry-v0.3.8.dmg.sha256)` passed.
  - DMG SHA-256 is `1b7208e286fe93a096be17443c046aa1c3f899c01d51aa8db3734d588b18a307`.

## Next Direction

- Complete v0.3.8 release candidate verification and publish `release/v0.3.8`.
- Keep `v0.4.0` focused on more providers and generic provider capabilities.
