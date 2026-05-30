# v0.3.6-Refactor Runtime Hardening

## Goal

在 `v0.3.6-Refactor` 分支上，对本轮重构审阅中指出的低风险 runtime 边界问题做最小范围收口，保持现有功能和 UI 不变，并按正式流程覆盖 `release/v0.3.6-Refactor` tag 和 GitHub Release。

## Status

- [x] Confirm `v0.3.6-Refactor` is already checked out in `.worktrees/v0.3.6-Refactor`.
- [x] Read current stale root planning files and identify they still described v0.3.2.
- [x] Create focused implementation plan: `docs/superpowers/plans/2026-05-30-v0.3.6-refactor-hardening_zh.md`.
- [x] Add RED test for inferred default provider semantics.
- [x] Implement optional default provider resolution and registration validation.
- [x] Change Console credential-management fallback from permissive to defensive.
- [x] Document lightweight provider factory expectations.
- [x] Run `swift run APIInquiryCoreTestsRunner`, `swift build`, and `git diff --check`.
- [x] Run agent code review and address blocking findings only.
- [x] Prepare the branch for commit and push.
- [x] Commit and push runtime hardening changes.
- [x] Update release notes for runtime hardening.
- [ ] Run final release verification and package DMG.
- [ ] Move `release/v0.3.6-Refactor` tag to the final release commit.
- [ ] Overwrite GitHub Release notes and assets.
- [ ] Verify remote tag, release assets, checksum, and branch state.

## Decisions

- Keep UI, user-visible behavior, Keychain storage, provider list, and provider IDs unchanged.
- Use `ProviderRegistration` as the runtime metadata source; do not reintroduce `ProviderCatalog.default` into production runtime paths.
- If `defaultProviderID` is omitted, infer it from the first registration instead of silently depending on the built-in registry default.
- If descriptor metadata is unexpectedly unavailable, Console credential-management actions should fail closed.
- Leave `MenuBarBalanceViewModel` default convenience init in place unless tests or review show it is actively harmful.

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| `git switch v0.3.6-Refactor` failed in main worktree | Branch was already attached to `.worktrees/v0.3.6-Refactor` | Continue work in the existing branch worktree |
| `swift run APIInquiryCoreTestsRunner` failed in sandbox | SwiftPM needed to write user-level clang/Swift caches | Reran with approved `swift run` escalation |
