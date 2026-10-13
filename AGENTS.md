# AGENTS.md

`CLAUDE.md` (a local companion file, not part of this repository) is the authoritative instruction file — read it for architecture, provider abstraction, credential storage, and release workflow. This file inlines only the facts an agent is most likely to get wrong.

## Stale instruction files

`AGENT.md` / `AGENT_zh.md` describe the **first release only** (DeepSeek balance-only) and are out of date. The app is now v0.3.15, multi-provider (DeepSeek + Zhipu GLM Coding Plan + Codex session quota + Codex manual-reset credits). Do **not** trust scope or architecture claims in `AGENT.md` — trust the code (and the local `CLAUDE.md`).

## Withdrawn Anthropic support

Anthropic/Claude support existed only in **v0.3.16–v0.3.20** (local login plus a browser-session source). On 2026-10-13 those releases and tags were withdrawn, `main` was reset to **v0.3.15** (`3052715`), and the newer objects were purged locally. So this codebase has **no Anthropic provider**: `ProviderID` has no `claude` case and no Claude credential/browser code exists. Do not assume, re-add, or document Claude support; docs that mention it describe withdrawn work. The last version with Anthropic support in local history no longer exists — if it is ever needed, it must be rebuilt from scratch.

## CI

`.github/workflows/ci.yml` — added in `1e04433` (2026-07-07) and unchanged since, so it is exactly the workflow of v0.3.15 — runs on pushes to `main` and `v0.3.*` / `v0.4.*` and on pull requests to `main`, on `macos-latest`: `actions/checkout@v4` → `swift --version` → `swift run APIInquiryCoreTestsRunner` → `swift build`. macOS runners queue slowly, so a run can sit queued for a long time.

## Commands

```bash
swift run APIInquiryCoreTestsRunner   # tests (NOT `swift test`, NOT XCTest)
swift build                            # compile all targets
Scripts/run-local-app.sh               # build + launch .build/APIInquiry.app
Scripts/build-local-app.sh             # build local app bundle, no launch
```

Release packaging only at release-candidate stage: `Scripts/package-mac-app.sh` → `dist/API Inquiry.app` (ad-hoc signed), `Scripts/package-dmg.sh` → `dist/API-Inquiry-vX.Y.Z.dmg` + `.sha256`, then `Scripts/clean-development-apps.sh`.

## Tests (critical: non-XCTest)

The dev machine has only Command Line Tools, so tests use a **custom executable runner**, not XCTest. Defaulting to `swift test` / XCTest is the #1 mistake here.

- To add a test suite: write a `SomethingTests` type with `static func run(using harness: TestHarness)` (add `async` if it awaits), then register it in the call list in `Sources/APIInquiryCoreTestsRunner/main.swift` — sync suites call `.run(using:)`, async suites `await ...run(using:)`.
- Assert via `harness.expectEqual` / `expectTrue` / `expectThrowsBalanceProviderError`.
- No single-test filter; the runner executes everything and exits non-zero on any failure. Expected output: `PASS: N expectations`.
- Fake keys + mocked network only — never real credentials.

## Branch and worktrees

- Default branch is `main` (not `master`). Do not implement on `main`.
- Implementation happens in isolated git worktrees. Per-version worktrees live under `.worktrees/v0.3.x/`. Follow the plan in `docs/superpowers/plans/` task by task; commit per completed task; use TDD for behavior changes.

## Architecture gotchas (see the code, or the local `CLAUDE.md`, for full detail)

- Two SwiftPM targets: `APIInquiryCore` (all logic, UI-independent, where tests live) and `APIInquiryApp` (SwiftUI views + AppKit glue, depends on Core). Keep testable logic in Core.
- **Codex manual-reset credits are a parallel subsystem, not a `BalanceProvider`.** Don't try to fit credits data into `ProviderSnapshot` — see `CodexManualResetCreditsProvider` / its own protocol.
- `BuiltInProviderRegistry.default` is the single source of truth wiring `ProviderID` → `ProviderDescriptor` + `makeProvider`. Adding a provider touches this chain.
- `CodexCredentialStore` decorates the Keychain store and reads `$CODEX_HOME/auth.json` / `~/.codex/auth.json` read-only for the Codex account.

## Conventions

- **Security**: never commit/log/print/display a real API key, Codex access token, session token, or account id. After a key is saved, UI shows only configured/replace/delete states.
- **Bilingual docs**: substantial planning/spec/README docs are paired — English `<name>.md` and Chinese `<name>_zh.md`. Any change to one must be synced to the other. See `docs/superpowers/documentation-conventions.md`.
- **User conversation is usually in Chinese**; prefer asking the user to review the Chinese doc version.
- **Releases**: bump `Scripts/version.env` so APP_VERSION, BUILD_NUMBER, RELEASE_TAG, DMG_BASENAME, VOLUME_NAME all match; verify the built app's `CFBundleShortVersionString`. Release notes are user-facing copy grouped into New Features / App Optimization / Bug Fixes (omit empty sections) — describe perceptible impact, not internal type names or file paths.
