# AGENTS.md

`CLAUDE.md` (a local companion file, not part of this repository) is the authoritative instruction file — read it for architecture, provider abstraction, credential storage, and release workflow. This file inlines only the facts an agent is most likely to get wrong.

## Stale instruction files

`AGENT.md` / `AGENT_zh.md` describe the **first release only** (DeepSeek balance-only) and are out of date. The app is multi-provider: DeepSeek balance, Zhipu GLM Coding Plan, Codex session quota, Codex manual-reset credits, and OpenCode usage — the last of which is on `main` but not yet released (the latest release, v0.3.16, predates it). Do **not** trust scope or architecture claims in `AGENT.md` — trust the code (and the local `CLAUDE.md`).

## Withdrawn Anthropic support

Anthropic/Claude support existed only in **v0.3.16–v0.3.20** (local login plus a browser-session source). On 2026-10-13 those releases and tags were withdrawn, `main` was reset to **v0.3.15** (`3052715`), and the newer objects were purged locally. So this codebase has **no Anthropic provider**: `ProviderID` has no `claude` case and no Claude credential/browser code exists. Do not assume, re-add, or document Claude support; docs that mention it describe withdrawn work. The last version with Anthropic support in local history no longer exists — if it is ever needed, it must be rebuilt from scratch.

**v0.3.16 was reused.** On 2026-10-30 the number `0.3.16` (build 21) was released again for the Codex Credits display fix. The current `release/v0.3.16` tag and GitHub Release carry that fix, not the withdrawn Anthropic work.

## CI

`.github/workflows/ci.yml` ("Release verification") runs **only on `release/*` tags** (plus manual dispatch). Every push and PR used to trigger it, but the `macos-latest` runners queue for hours, which cost far more than the check is worth: the same two commands (`swift run APIInquiryCoreTestsRunner`, `swift build`) finish in seconds locally. Day-to-day gating is the local test runner; CI is the independent-environment check at release time. It was briefly disabled on 2026-10-30 while the trigger change landed, and is active again; if `gh workflow list` ever shows it as `disabled_manually`, run `gh workflow enable ci.yml`, otherwise tag pushes will not run it.

## `main` branch ruleset

`main` is protected by the repository ruleset **"main protection"** (enabled 2026-10-31): no deletions, no force pushes, and every change must land through a pull request. Two settings look like omissions and are not — do not "fix" them:

- **Required approvals are 0.** The user is the only collaborator and GitHub forbids approving your own pull request, so any non-zero count would make every PR permanently unmergeable.
- **Required status checks are off.** CI runs only for `release/*` tags (see above), so a PR produces zero check runs; marking a check required would block merges until a macOS runner happened to finish.

The ruleset has no bypass list, so it binds the agent too: `git push origin main` fails with `GH006` (protected branch). Push a branch and open a PR instead. Rewriting `main`'s history — e.g. the 2026-10-13 reset to v0.3.15 — now means disabling the ruleset in Settings → Rules, doing the rewrite, then re-enabling it; that extra step is the point. Feature branches are unaffected (only the default branch is targeted), and `delete_branch_on_merge` is on, so merged PR branches are removed automatically.

## Working protocol (staged, not end-to-end)

Unless the user explicitly asks for a one-shot end-to-end delivery, every change — features, fixes, and polish — moves through these five stages, and the agent **stops and reports at each stage** instead of silently running 1→5:

1. **Issue first.** File the problem as a GitHub issue (`gh issue create`) with the observed behaviour, expected behaviour, and where in the code it lives. No implementation before there is an issue (or the user explicitly waives it).
2. **Joint diagnosis.** Locate the cause *with* the user: read the code, then prove the hypothesis with a measurement, a demo, or a failing test. Present evidence (numbers, screenshots, test output) and 2–3 candidate solutions with trade-offs. **Wait for the user to choose** before writing production code.
3. **Implement + PR.** Only then change code, keep the diff scoped to the chosen issue, run `swift run APIInquiryCoreTestsRunner`, and open a PR that states the evidence and the verification steps.
4. **Joint testing.** The agent verifies what it can (tests, local build, screenshots); the user verifies the perceptible behaviour (menu bar, Console, DMG). Both must pass.
5. **Ask, then merge.** Opening a PR is never permission to merge it. After stage 4 sign-off, **ask the user explicitly** ("可以合入吗？") and wait for a yes. Rebase-merge only on that explicit approval, then delete the branch and confirm the local suite on `main`. This applies to every PR, including docs and chore changes, and it is per-PR: an approval for one PR does not carry to the next. Merging is the irreversible step — it moves `main`, closes issues, and changes what everyone builds from — so the user keeps the pacing.

Why: the user wants to learn the reasoning (diagnosis, trade-offs, verification), not only receive finished diffs. Short-circuiting stages hides exactly that reasoning. Asking for "just fix it" or "one-shot" is the explicit opt-out. The same applies to merging: the user reviews the diff and the evidence before `main` moves, so "提交 PR" means "open the PR", not "merge it".

## Commands

```bash
swift run APIInquiryCoreTestsRunner   # tests (NOT `swift test`, NOT XCTest)
swift build                            # compile all targets
Scripts/run-local-app.sh               # build + launch .build/APIInquiry.app
Scripts/build-local-app.sh             # build local app bundle, no launch
```

**`swift build` needs the Xcode toolchain here.** `xcode-select` points at Command Line Tools, whose SDK cannot resolve `SwiftUI.StateMacro`, so a bare `swift build` fails with `SwiftUI.State: 'State()' declared here` followed by `error: Build failed`. Prefix it: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`. `swift run APIInquiryCoreTestsRunner` does **not** need the prefix — `APIInquiryCore` imports no SwiftUI — so the daily test loop runs as written.

Release packaging only at release-candidate stage: `Scripts/package-mac-app.sh` → `dist/API Inquiry.app` (ad-hoc signed), `Scripts/package-dmg.sh` → `dist/API-Inquiry-vX.Y.Z.dmg` + `.sha256`, then `Scripts/clean-development-apps.sh`. Full checklist and failure table: `docs/release-runbook.md` / `docs/release-runbook_zh.md`.

## Build identity and local runs

- Local builds carry version `0.0.0-dev` plus `APIInquiryGitCommit` (and `APIInquiryGitDirty` when the tree is dirty) in `Info.plist`; the Console renders it as "开发版本 · 提交 abc1234". This is deliberate — version numbers exist only in release artifacts, and `Scripts/package-mac-app.sh` refuses to package a `0.0.0-dev` build. Do not "fix" it by hard-coding a release version into the bundle.
- **Every rebuild changes the code signature, so the next launch asks for Keychain access again** ("API Inquiry 想要使用你储存在钥匙串…"). The user must click 允许 / 始终允许; never type a password yourself, and do not report that dialog as a code bug.

## Release packaging gotchas (learned the hard way in v0.3.16)

- **Build with the Xcode toolchain.** This machine's Command Line Tools SDK does not match `/usr/bin/swift`; Release builds then fail with bogus semantic errors such as `cannot assign to property: 'self' is immutable` on a `@State` assignment. Prefix packaging with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **SwiftPM's default build system is the Xcode one now.** Products land in `.build/out/Products/<Configuration>/` and the resource bundle is `APIInquiry_APIInquiryApp.bundle/Contents/Resources/`, not the flat layout older releases had. Never copy resources with `find -maxdepth 1`; the script searches recursively and aborts when `AppIcon.icns` is missing, because an empty `Contents/Resources` silently ships a generic Finder icon and text-only provider logos.
- **Build with `--build-system native`, or the app loses the macOS 26 design.** SwiftPM's Xcode build system records `LC_BUILD_VERSION sdk` as the deployment target (13.0), which opts the binary out of the new design: the Console's add-provider control becomes a wide legacy pop-up button and the menu bar panel falls back to old window chrome. The native system records the real SDK (26.5/27.0) and matches v0.3.15. Both packaging scripts pass the flag; verify with `otool -l <binary> | grep -A4 LC_BUILD_VERSION` (expect `sdk 2x.y`, not `13.0`).
- **Never trust a scripted Finder to lay out the DMG window.** Finder only applies and persists view options (background picture, 152 pt icons, positions) while it is frontmost and the window is open; scripted from the background it drops them with no error and the volume gets a ~6 KB `.DS_Store` stub. `package-dmg.sh` activates Finder, waits for the window, polls `.DS_Store` for the `dmg-background.png` alias before closing and detaching, and rejects any DMG whose `.DS_Store` lacks that alias. A 10 KB `.DS_Store` is the healthy size.
- **Acceptance is the app inside the mounted DMG**, not `dist/API Inquiry.app`: the Desktop copy keeps picking up FileProvider/Finder metadata and then fails `codesign --verify --deep --strict` with "resource fork, Finder information, or similar detritus". Strip it with `xattr -cr` before verifying local copies.
- **A polluted shell env follows the app into everything it opens.** This harness is an Electron app and exports `ELECTRON_RUN_AS_NODE=1`; LaunchServices passes the caller's environment to the app it launches, so an app started from this shell that later calls `NSWorkspace.open` on a `.jsonc`/`.json` file hands that variable to VS Code, which then starts in Node mode and exits instantly while `NSWorkspace.open` still returns true (no error anywhere). `Scripts/run-local-app.sh` unsets `ELECTRON_RUN_AS_NODE`/`NODE_OPTIONS` before launching; do the same by hand if you start the app another way.
- **Sandboxed automation needs relaxed permissions**: SwiftPM's own sandbox fails with `sandbox-exec: sandbox_apply: Operation not permitted` (use `--disable-sandbox`), `hdiutil` cannot create images, and the three Keychain expectations fail with `unexpectedStatus(100001)`. `PASS: N expectations` requires running outside that sandbox; CI is the release gate otherwise.
- **Version numbers can be reused deliberately.** `0.3.16` was released again on 2026-10-30 after the withdrawn `0.3.16`–`0.3.20` Anthropic builds; check `git ls-remote --tags origin` and the releases API before bumping, and record any reuse here.

## Tests (critical: non-XCTest)

The default toolchain is Command Line Tools (`xcode-select -p` points at it, and that SDK ships no `XCTest.framework`; Xcode is installed but only selected through `DEVELOPER_DIR`), so tests use a **custom executable runner**, not XCTest. Defaulting to `swift test` / XCTest is the #1 mistake here.

- To add a test suite: write a `SomethingTests` type with `static func run(using harness: TestHarness)` (add `async` if it awaits), then register it in the call list in `Sources/APIInquiryCoreTestsRunner/main.swift` — sync suites call `.run(using:)`, async suites `await ...run(using:)`.
- Assert via `harness.expectEqual` / `expectTrue` / `expectThrowsBalanceProviderError`.
- No single-test filter; the runner executes everything and exits non-zero on any failure. Expected output: `PASS: N expectations`.
- Fake keys + mocked network only — never real credentials.

## Branch and worktrees

- Default branch is `main` (not `master`). Do not implement on `main`.
- Implementation happens in isolated git worktrees named after the work, e.g. `.worktrees/issue-13-config-entry/`, `.worktrees/docs/main-ruleset/`. Commit per completed task; use TDD for behavior changes.
- Current work is **issue-driven, not plan-driven**: `docs/superpowers/plans/` holds per-release plans only up to v0.3.15 and is historical. Issues live in GitHub Issues (`docs/agents/issue-tracker.md`).
- **Only one session should build or install at a time.** Two agents working the same checkout and `/Applications` copy produced version confusion; give each session its own worktree and do not run concurrent `run-local-app.sh` loops.

## Architecture gotchas (see the code, or the local `CLAUDE.md`, for full detail)

- Two library targets plus a test executable: `APIInquiryCore` (all logic, UI-independent, where the tests live), `APIInquiryApp` (SwiftUI views + AppKit glue, depends on Core), and `APIInquiryCoreTestsRunner` (the custom runner — not an XCTest target). Keep testable logic in Core.
- **Codex manual-reset credits are a parallel subsystem, not a `BalanceProvider`.** Don't try to fit credits data into `ProviderSnapshot` — see `CodexManualResetCreditsProvider` / its own protocol.
- `BuiltInProviderRegistry.default` is the single source of truth wiring `ProviderID` → `ProviderDescriptor` + `makeProvider`. Adding a provider touches this chain. The current `ProviderID` cases are `deepseek`, `zhipuCodingPlan`, `codex`, `opencode`.
- Credential stores form a decorator chain, outermost first: `OpenCodeCredentialStore` → `CodexCredentialStore` → `KeychainCredentialStore` (composed once in `APIInquiryApp.init`). Codex reads `$CODEX_HOME/auth.json` / `~/.codex/auth.json` read-only; every other provider's key lives in the Keychain (OpenCode's account is `opencode-api-key`). A decorator must forward whatever it does not override, or the layers beneath silently lose behaviour.

## Conventions

- **Security**: never commit/log/print/display a real API key, Codex access token, session token, or account id. After a key is saved, UI shows only configured/replace/delete states.
- **Bilingual docs**: substantial planning/spec/README docs are paired — English `<name>.md` and Chinese `<name>_zh.md`. Any change to one must be synced to the other. See `docs/superpowers/documentation-conventions.md`.
- **User conversation is usually in Chinese**; prefer asking the user to review the Chinese doc version.
- **Issue tracking and triage**: `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md` (label vocabulary), `docs/agents/domain.md` (`CONTEXT.md` plus `docs/adr/`, created lazily).
- **Releases**: bump `Scripts/version.env` so APP_VERSION, BUILD_NUMBER, RELEASE_TAG, DMG_BASENAME, VOLUME_NAME all match; verify the built app's `CFBundleShortVersionString`. Release notes are user-facing copy grouped into New Features / App Optimization / Bug Fixes (omit empty sections) — describe perceptible impact, not internal type names or file paths.
