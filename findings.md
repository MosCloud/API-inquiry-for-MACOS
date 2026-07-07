# Current Findings

## Repository State

- Current branch/worktree: `v0.3.11` at `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.11`.
- Branch base: `main` commit `fc52638` (`feat: prepare v0.3.10 release`).
- Latest released version in this worktree is still `v0.3.10`; `v0.3.11` implementation has not started.
- The root `main` worktree has unrelated untracked `CLAUDE.md` and `docs/reviews/`; they were not copied, modified, or removed while creating `v0.3.11`.

## Project Shape

- Swift Package Manager project targeting macOS 13+.
- Main products:
  - `APIInquiryCore`
  - `APIInquiryCoreTestsRunner`
  - `APIInquiryApp`
- Standard verification commands:
  - `swift run APIInquiryCoreTestsRunner`
  - `swift build`
  - `Scripts/run-local-app.sh`
  - `Scripts/package-dmg.sh`
- Tests use a custom executable runner, not XCTest.

## Current Mainline Capabilities

- Native macOS menu bar app for API provider status.
- Supports DeepSeek prepaid balance, Zhipu GLM Coding Plan usage, Codex/ChatGPT quota windows, and Codex manual-reset credits/details.
- Multi-provider Console with Home, API, and Settings sections.
- Primary Provider can be displayed in the menu bar.
- API keys are stored in macOS Keychain; Codex reads local Codex auth read-only before fallback.
- Chinese/English localization with `Auto / 中文 / English` selection.
- Release packaging uses ad-hoc signed DMG; Apple notarization is still not enabled.

## v0.3.11 Planning Findings

- The 2026-07-07 quality assessment is directionally sound, but its execution order mixes patch-sized fixes with larger architecture and distribution work.
- `v0.3.11` should be a focused quality release, not a broad refactor release.
- The highest-value immediate fixes are:
  - CI baseline.
  - Semantic quota-window modeling for `"5h"` and `"Week"`.
  - Stable Codex manual-reset credential tracking instead of `String.hashValue`.
  - User-visible diagnostics for malformed local Codex `auth.json`.
  - Single Console feedback channel and unified window-size constants.
  - Key light-mode contrast fixes.
  - Shared refresh feedback state between menu refresh and manual-reset refresh.
  - Version/release documentation.
- Larger but serious items should be delayed:
  - Full Codex auxiliary-feed architecture.
  - `ProviderSnapshot` display adapter rewrite.
  - Full `MenuBarContentView` split.
  - Full design-token migration.
  - Sparkle automatic updates, Homebrew Cask, and low-quota notifications.

## Verification Evidence

- Fresh `v0.3.11` baseline:
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 608 expectations`.
  - `swift build` passed.
- Initial sandboxed Swift runs failed because SwiftPM/Clang could not write user-level module cache files under `/Users/zbw/.cache/clang/ModuleCache`; serial escalated runs passed.

## Important Docs And Plans

- v0.3.11 quality-fix plan:
  - `docs/superpowers/plans/2026-07-07-v0.3.11-quality-fixes.md`
  - `docs/superpowers/plans/2026-07-07-v0.3.11-quality-fixes_zh.md`
- Source assessment in the root worktree:
  - `docs/reviews/2026-07-07-quality-assessment-and-improvement-plan_zh.md`
  - `docs/reviews/2026-07-07-quality-assessment-and-improvement-plan.md`

## Next Direction

- Review the Chinese v0.3.11 plan with the user first.
- Execute the plan task by task with TDD where Core behavior changes are involved.
- Keep `v0.4.0` provider-generalization work separate.
