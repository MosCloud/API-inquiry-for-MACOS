# AGENTS.md

`CLAUDE.md` (a local companion file, not part of this repository) is the authoritative instruction file — read it for architecture, provider abstraction, credential storage, and release workflow. This file inlines only the facts an agent is most likely to get wrong.

## Stale instruction files

`AGENT.md` / `AGENT_zh.md` describe the **first release only** (DeepSeek balance-only) and are out of date. The app is now v0.3.16, multi-provider (DeepSeek + Zhipu GLM Coding Plan + Codex session quota + Codex manual-reset credits). Do **not** trust scope or architecture claims in `AGENT.md` — trust the code (and the local `CLAUDE.md`).

## Withdrawn Anthropic support

Anthropic/Claude support existed only in **v0.3.16–v0.3.20** (local login plus a browser-session source). On 2026-10-13 those releases and tags were withdrawn, `main` was reset to **v0.3.15** (`3052715`), and the newer objects were purged locally. So this codebase has **no Anthropic provider**: `ProviderID` has no `claude` case and no Claude credential/browser code exists. Do not assume, re-add, or document Claude support; docs that mention it describe withdrawn work. The last version with Anthropic support in local history no longer exists — if it is ever needed, it must be rebuilt from scratch.

**v0.3.16 was reused.** On 2026-10-30 the number `0.3.16` (build 21) was released again for the Codex Credits display fix. The current `release/v0.3.16` tag and GitHub Release carry that fix, not the withdrawn Anthropic work.

## CI

`.github/workflows/ci.yml` — added in `1e04433` (2026-07-07) and unchanged since, so it is exactly the workflow of v0.3.15 — runs on pushes to `main` and `v0.3.*` / `v0.4.*` and on pull requests to `main`, on `macos-latest`: `actions/checkout@v4` → `swift --version` → `swift run APIInquiryCoreTestsRunner` → `swift build`. macOS runners queue slowly, so a run can sit queued for a long time.

## Commands

```bash
swift run APIInquiryCoreTestsRunner   # tests (NOT `swift test`, NOT XCTest)
swift build                            # compile all targets
Scripts/run-local-app.sh               # build + launch .build/APIInquiry.app
Scripts/build-local-app.sh             # build local app bundle, no launch
```

Release packaging only at release-candidate stage: `Scripts/package-mac-app.sh` → `dist/API Inquiry.app` (ad-hoc signed), `Scripts/package-dmg.sh` → `dist/API-Inquiry-vX.Y.Z.dmg` + `.sha256`, then `Scripts/clean-development-apps.sh`. Full checklist and failure table: `docs/release-runbook.md` / `docs/release-runbook_zh.md`.

## Release packaging gotchas (learned the hard way in v0.3.16)

- **Build with the Xcode toolchain.** This machine's Command Line Tools SDK does not match `/usr/bin/swift`; Release builds then fail with bogus semantic errors such as `cannot assign to property: 'self' is immutable` on a `@State` assignment. Prefix packaging with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **SwiftPM's default build system is the Xcode one now.** Products land in `.build/out/Products/<Configuration>/` and the resource bundle is `APIInquiry_APIInquiryApp.bundle/Contents/Resources/`, not the flat layout older releases had. Never copy resources with `find -maxdepth 1`; the script searches recursively and aborts when `AppIcon.icns` is missing, because an empty `Contents/Resources` silently ships a generic Finder icon and text-only provider logos.
- **Build with `--build-system native`, or the app loses the macOS 26 design.** SwiftPM's Xcode build system records `LC_BUILD_VERSION sdk` as the deployment target (13.0), which opts the binary out of the new design: the Console's add-provider control becomes a wide legacy pop-up button and the menu bar panel falls back to old window chrome. The native system records the real SDK (26.5/27.0) and matches v0.3.15. Both packaging scripts pass the flag; verify with `otool -l <binary> | grep -A4 LC_BUILD_VERSION` (expect `sdk 2x.y`, not `13.0`).
- **Never trust a scripted Finder to lay out the DMG window.** Finder only applies and persists view options (background picture, 152 pt icons, positions) while it is frontmost and the window is open; scripted from the background it drops them with no error and the volume gets a ~6 KB `.DS_Store` stub. `package-dmg.sh` activates Finder, waits for the window, polls `.DS_Store` for the `dmg-background.png` alias before closing and detaching, and rejects any DMG whose `.DS_Store` lacks that alias. A 10 KB `.DS_Store` is the healthy size.
- **Acceptance is the app inside the mounted DMG**, not `dist/API Inquiry.app`: the Desktop copy keeps picking up FileProvider/Finder metadata and then fails `codesign --verify --deep --strict` with "resource fork, Finder information, or similar detritus". Strip it with `xattr -cr` before verifying local copies.
- **Sandboxed automation needs relaxed permissions**: SwiftPM's own sandbox fails with `sandbox-exec: sandbox_apply: Operation not permitted` (use `--disable-sandbox`), `hdiutil` cannot create images, and the three Keychain expectations fail with `unexpectedStatus(100001)`. `PASS: N expectations` requires running outside that sandbox; CI is the release gate otherwise.
- **Version numbers can be reused deliberately.** `0.3.16` was released again on 2026-10-30 after the withdrawn `0.3.16`–`0.3.20` Anthropic builds; check `git ls-remote --tags origin` and the releases API before bumping, and record any reuse here.

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
