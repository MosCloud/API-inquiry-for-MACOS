# Current Task Plan

## Goal

Prepare the `v0.3.11` branch from `main` and record a detailed quality-fix plan for the highest-priority issues identified in the 2026-07-07 quality assessment, while keeping `v0.4.0` provider-generalization work out of scope.

## Current Status

- [x] Create isolated worktree branch `v0.3.11` from current `main`.
- [x] Confirm the root `main` worktree has unrelated untracked files and leave them untouched.
- [x] Review the 2026-07-07 quality assessment and current roadmap/release state.
- [x] Verify fresh `v0.3.11` baseline with `swift run APIInquiryCoreTestsRunner`.
- [x] Verify fresh `v0.3.11` baseline with `swift build`.
- [x] Record the v0.3.11 implementation plan in paired English and Chinese plan docs.
- [x] Refresh root `task_plan.md`, `findings.md`, and `progress.md` for the new branch context.
- [ ] Review the recorded plan with the user before implementation starts.
- [ ] Implement v0.3.11 tasks in small, reviewable commits.
- [ ] Verify final release candidate with `git diff --check`, `swift run APIInquiryCoreTestsRunner`, `swift build`, local app launch, DMG packaging, Info.plist version checks, codesign verification, `hdiutil verify`, and checksum verification.

## Decisions

- `v0.3.11` is a quality-fix release after `v0.3.10`, not the `v0.4.0` provider-expansion release.
- Immediate scope: CI baseline, quota-window semantics, Codex manual-reset credential fingerprinting, Codex auth-file diagnostics, Console feedback/window-size cleanup, key light-mode contrast fixes, shared refresh feedback state, and release docs.
- Deferred scope: full Codex auxiliary-feed integration, `ProviderSnapshot` display-adapter rewrite, complete `MenuBarContentView` split, full menu-panel tokenization, Sparkle, Homebrew Cask, and low-balance notifications.
- The root `main` worktree currently has untracked `CLAUDE.md` and `docs/reviews/`; those files remain untouched from this branch setup.
- SwiftPM verification needs user-level Swift/Clang module cache access in this environment; sandboxed Swift runs can fail until rerun with approved escalation.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| SwiftPM/Clang cache write blocked in sandbox | `swift run APIInquiryCoreTestsRunner` and `swift build` attempted to write under `/Users/zbw/.cache/clang/ModuleCache` | Re-ran the commands serially with approved escalation; both passed |
| Parallel Swift commands contended on `.build` | `swift run APIInquiryCoreTestsRunner` and `swift build` were started together | Switched to serial verification |
| Initial patch applied to root worktree | `apply_patch` used the default root cwd instead of the new worktree | Restored the root tracked docs and deleted the mistakenly added root plan files, then re-applied patches with absolute paths into `.worktrees/v0.3.11` |

## Next Suggested Work

- Review `docs/superpowers/plans/2026-07-07-v0.3.11-quality-fixes_zh.md` with the user.
- After approval, execute Task 1 through Task 9 in order, with tests and commits at each task boundary.
