# Current Progress

## 2026-05-20

- Created the original persistent planning files for the v0.3.2 localization and language switching work.
- Planned Chinese localization, `Auto / 中文 / English` language selection, and terminology decisions.

## 2026-05-29

- Completed the v0.3.6 refactor branch focused on provider metadata centralization, ViewModel coordinator unification, Console UI splitting, formatter splitting, visual catalog cleanup, concurrent multi-provider refresh, and Settings version display.
- Released `release/v0.3.6-Refactor` as a prerelease with DMG assets.

## 2026-05-30

- Continued the architecture cleanup after review:
  - made `MultiProviderBalanceCoordinator` initialize from `ProviderRegistration`
  - injected descriptor-owned credential accounts into `BalanceRefreshController`
  - removed provider metadata convenience from `BalanceProvider`
  - removed provider-based formatter overloads
  - removed production single-provider ViewModel entrypoints
  - simplified test provider mocks
- Added `ProviderRuntimeTestFixtures` for tests.
- Added provider registration runtime refactor plan docs in English and Chinese.
- Verified with `swift run APIInquiryCoreTestsRunner` and `swift build`.
- Got a read-only quality review from a subagent; no blocking issues found.
- Published an updated `v0.3.6-Refactor` release:
  - refreshed release notes
  - regenerated DMG and checksum
  - moved tag `release/v0.3.6-Refactor` to the refreshed release commit
  - uploaded replacement GitHub Release assets
- Fast-forwarded `v0.3.6-Refactor` into `main` and pushed `main`.
- Updated README screenshots:
  - MenuBar
  - Console Home
  - Console API
  - Console Setting
- Pushed README screenshot update to `main` as `c48a22b`.
- Refreshed root planning files (`findings.md`, `progress.md`, `task_plan.md`) so they reflect current `main` instead of v0.3.2.
- Synchronized README and `docs/roadmap.md` so the latest released version is explicitly `v0.3.6-Refactor`.

## Current State

- `main` and `origin/main` are synchronized after the README screenshot and planning refresh work.
- Latest released version is `v0.3.6-Refactor`.
- `release/v0.3.6-Refactor` is at `9947bde`.
- Latest `v0.3.6-Refactor` release assets are available on GitHub Release `release/v0.3.6-Refactor`.
- Root planning files have been refreshed from the obsolete v0.3.2 snapshot to the current mainline state.

## Open Notes

- `.superpowers/` remains an untracked local directory and has not been modified.
- Next substantial implementation should start from a fresh v0.4.0 plan.
