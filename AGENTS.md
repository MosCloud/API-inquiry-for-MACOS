# AGENTS.md

This file is the agent contract. `CLAUDE.md` is a local, untracked companion with more architecture detail; it is not distributed and can lag behind the code, so trust the code when they disagree. `AGENT.md` / `AGENT_zh.md` are redirect stubs kept only so links in older plans still resolve.

## Withdrawn Anthropic support

Anthropic/Claude support existed only in **v0.3.16–v0.3.20** (local login plus a browser-session source). On 2026-10-13 those releases and tags were withdrawn, `main` was reset to **v0.3.15** (`3052715`), and the newer objects were purged locally. So this codebase has **no Anthropic provider**: `ProviderID` has no `claude` case and no Claude credential/browser code exists. Do not assume, re-add, or document Claude support; docs that mention it describe withdrawn work. The last version with Anthropic support in local history no longer exists — if it is ever needed, it must be rebuilt from scratch.

**v0.3.16 was reused.** On 2026-10-30 the number `0.3.16` (build 21) was released again for the Codex Credits display fix. The current `release/v0.3.16` tag and GitHub Release carry that fix, not the withdrawn Anthropic work.

## CI

`.github/workflows/ci.yml` ("Release verification") runs **only on `release/*` tags** (plus manual dispatch). Every push and PR used to trigger it, but the `macos-latest` runners queue for hours — far more than the check is worth, since both checks take seconds locally (see Commands). Day-to-day gating is the local run; CI is the independent-environment check at release time. If `gh workflow list` ever shows it as `disabled_manually`, run `gh workflow enable ci.yml`, otherwise tag pushes will not run it.

## `main` is pull-request only

The `main protection` ruleset blocks deletions, force pushes, and direct pushes: push a branch and open a PR.

- **Required approvals are 0.** The user is the only collaborator and GitHub forbids approving your own PR, so any non-zero count would make every PR unmergeable.
- **Required status checks are off.** CI runs only for `release/*` tags, so a PR produces no check runs; requiring one would block merges indefinitely.
- There is no bypass list, so the ruleset binds the agent too — a direct `git push origin main` is rejected.
- Rewriting `main`'s history (e.g. the 2026-10-13 reset to v0.3.15) is the **user's** call: they disable the ruleset, rewrite, and re-enable it. Do not attempt it.
- Feature branches are unaffected. GitHub deletes merged PR branches; clean up locally with `git worktree remove <path>` and then `git branch -D <branch>` (rebase-merge rewrites SHAs, so `-d` refuses).

## Working protocol (staged, not end-to-end)

Unless the user explicitly asks for a one-shot end-to-end delivery, every change — features, fixes, and polish — moves through these five stages, and the agent **stops and reports at each stage** instead of silently running 1→5:

1. **Issue first.** File the problem as a GitHub issue (`gh issue create`) with the observed behaviour, expected behaviour, and where in the code it lives. No implementation before there is an issue (or the user explicitly waives it).
2. **Joint diagnosis.** Locate the cause *with* the user: read the code, then prove the hypothesis with a measurement, a demo, or a failing test. Present evidence (numbers, screenshots, test output) and 2–3 candidate solutions with trade-offs. **Wait for the user to choose** before writing production code.
3. **Implement + PR.** Only then change code, keep the diff scoped to the chosen issue, run `Scripts/verify.sh` (tests **and** the app build; see Commands) — the tests never compile `APIInquiryApp` — and open a PR that states the evidence and the verification steps. A PR is ready when the tests pass, the app builds, the diff stays scoped, and every fact it touches in this file or in the release runbook is still true — stale documentation counts as a bug.
4. **Joint testing.** The agent verifies what it can (`Scripts/verify.sh`, screenshots where possible). For anything that changes what the app does — feature, UI, response behaviour — it then builds a side-by-side development copy with `Scripts/run-dev-app.sh`; the running app and `.build/APIInquiry.app` stay untouched, and the user tests that copy. Prefer `--fixtures <scenario>` for state and visual checks (in-memory credentials, no keychain prompt); use the real copy when credentials, network, packaging or system integration is what changed. Docs-, script- and tooling-only changes stop at `Scripts/verify.sh`. Merging waits for the user's sign-off.
5. **Ask, then merge.** Opening a PR is never permission to merge it. After stage 4 sign-off, **ask the user explicitly** ("可以合入吗？") and wait for a yes. Rebase-merge only on that explicit approval, then delete the branch and confirm the local suite on `main`. This applies to every PR, including docs and chore changes, and it is per-PR: an approval for one PR does not carry to the next. Merging is the irreversible step — it moves `main`, closes issues, and changes what everyone builds from — so the user keeps the pacing.

**Changes without a PR.** Repository settings (rulesets, labels, workflow toggles) and issue state are still the user's call: propose the exact command, apply it only on explicit approval, and paste the verification output into the issue before closing it.

Why: the user wants to learn the reasoning (diagnosis, trade-offs, verification), not only receive finished diffs. Short-circuiting stages hides exactly that reasoning. Asking for "just fix it" or "one-shot" is the explicit opt-out. The same applies to merging: the user reviews the diff and the evidence before `main` moves, so "提交 PR" means "open the PR", not "merge it".

## Commands

```bash
Scripts/verify.sh                                                     # tests + app build — the PR gate
Scripts/run-dev-app.sh                                                # side-by-side development copy for stage-4 checks
Scripts/run-dev-app.sh --fixtures stale                               # same copy with in-memory fixtures (no keychain prompt)
swift run APIInquiryCoreTestsRunner                                    # tests only — NOT `swift test`; compiles Core only
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build   # compiles every target, APIInquiryApp included
Scripts/run-local-app.sh                                               # build + launch .build/APIInquiry.app
Scripts/build-local-app.sh                                             # build the bundle, no launch
```

`xcode-select` points at Command Line Tools, which cannot resolve the SwiftUI macros, so a bare `swift build` still needs `DEVELOPER_DIR` (see the block above); Xcode is only needed to compile `APIInquiryApp` — Core work, tests and docs run on Command Line Tools alone. The two app scripts now select Xcode's developer directory themselves, abort with a readable message when no Xcode is installed, and fail the build when the product links against the deployment-target SDK (13.0) instead of a real one — that is the `--build-system native` regression guard. The test runner needs neither: it never compiles the app, so a missing `case` in an App-side `switch` passes every test and fails only `swift build`.

SwiftPM's own sandbox has to be off in scripted environments (`--disable-sandbox`); `hdiutil` cannot create images there, and three Keychain expectations fail with `unexpectedStatus(100001)`. `PASS: N expectations` and DMG packaging both require running outside that sandbox.

Release packaging only at release-candidate stage: `Scripts/package-mac-app.sh` → `dist/API Inquiry.app` (ad-hoc signed), `Scripts/package-dmg.sh` → `dist/API-Inquiry-vX.Y.Z.dmg` + `.sha256`, then `Scripts/clean-development-apps.sh`. Full checklist and failure table: `docs/release-runbook.md` / `docs/release-runbook_zh.md`.

## Build identity and local runs

- Local builds carry `0.0.0-dev` plus `APIInquiryGitCommit` / `APIInquiryGitDirty` in `Info.plist`; the Console shows "开发版本 · 提交 abc1234". Release versions come only from `Scripts/version.env` at packaging time, and `package-mac-app.sh` refuses to package a `0.0.0-dev` bundle — do not hard-code a version.
- A rebuild changes the ad-hoc signature, so the next launch asks for Keychain access. Ask the user to click 始终允许 and wait for that before reading provider data; the prompt is expected, not a bug.
- `run-local-app.sh` builds first and then runs `pkill -x APIInquiry`, which kills **every** copy — another session's dev build and the installed release. Only one session should launch the app at a time.
- `run-dev-app.sh` stages a side-by-side copy (`APIInquiryDevelopment`, display name "Development under <checkout>") under `/private/tmp/api-inquiry-development-<uid>-<worktree-id>/` and launches it with `open -n`; it never kills or relinks the running app. The copy registers as `com.api-inquiry.APIInquiry.development` and seeds its preferences once from the main domain, so both menu bar items can coexist. Quit the copy with `pkill -x APIInquiryDevelopment`. It has its own preferences domain but the same Keychain service, so credential checks still use the real items — expect the usual Keychain prompt after a rebuild.

## UI and product direction

Keep the UI simple, restrained, and lightly technical: fast quota-state scanning and lightweight configuration, not an analytics dashboard. Use status colour only for critical, warning, and healthy values plus direct feedback; keep surrounding labels and configuration surfaces calm, and prefer stable alignment and generous spacing over visual density.

The menu bar panel is for viewing and lightweight actions only. Multi-provider management belongs in Console: Home owns display strategy (Primary Provider), API owns credentials and local configuration, Settings owns app preferences.

## Release packaging gotchas (learned the hard way in v0.3.16)

- **Build with the Xcode toolchain.** `package-mac-app.sh` selects Xcode's developer directory itself (and aborts without it); a bare `swift build` still needs the prefix (see Commands).
- **Build-system choice moves the products.** With the default Xcode build system they land in `.build/out/Products/<Configuration>/`; with the `--build-system native` that both scripts pass they land in `.build/<configuration>/`, which is where `package-mac-app.sh` copies from. The resource bundle's layout differs between the two as well — search it recursively, never with `find -maxdepth 1`, and abort when `AppIcon.icns` is missing, because an empty `Contents/Resources` silently ships a generic icon and text-only logos.
- **Build with `--build-system native`, or the app loses the macOS 26 design.** SwiftPM's Xcode build system records `LC_BUILD_VERSION sdk` as the deployment target (13.0), which opts the binary out of the new design: the Console's add-provider control becomes a wide legacy pop-up button and the menu bar panel falls back to old window chrome. The native system records the real SDK (26.5/27.0) and matches v0.3.15. Both packaging scripts pass the flag; verify with `otool -l <binary> | grep -A4 LC_BUILD_VERSION` (expect `sdk 2x.y`, not `13.0`).
- **Never trust a scripted Finder to lay out the DMG window.** Finder only applies and persists view options (background picture, 152 pt icons, positions) while it is frontmost and the window is open; scripted from the background it drops them with no error and the volume gets a ~6 KB `.DS_Store` stub. `package-dmg.sh` activates Finder, waits for the window, polls `.DS_Store` for the `dmg-background.png` alias before closing and detaching, and rejects any DMG whose `.DS_Store` lacks that alias. A 10 KB `.DS_Store` is the healthy size.
- **Acceptance is the app inside the mounted DMG**, not `dist/API Inquiry.app`: the Desktop copy keeps picking up FileProvider/Finder metadata and then fails `codesign --verify --deep --strict` with "resource fork, Finder information, or similar detritus". Strip it with `xattr -cr` before verifying local copies.
- **A polluted shell env follows the app into everything it opens.** This harness is an Electron app and exports `ELECTRON_RUN_AS_NODE=1`; LaunchServices passes the caller's environment to the app it launches, so an app started from this shell that later calls `NSWorkspace.open` on a `.jsonc`/`.json` file hands that variable to VS Code, which then starts in Node mode and exits instantly while `NSWorkspace.open` still returns true (no error anywhere). `Scripts/run-local-app.sh` unsets `ELECTRON_RUN_AS_NODE`/`NODE_OPTIONS` before launching; do the same by hand if you start the app another way.
- **Version numbers can be reused deliberately.** `0.3.16` was released again on 2026-10-30 after the withdrawn `0.3.16`–`0.3.20` Anthropic builds; check `git ls-remote --tags origin` and the releases API before bumping, and record any reuse here.

## Tests (custom runner, not XCTest)

The package has no XCTest target: tests are a **custom executable runner**, so `swift test` cannot work here. Use `swift run APIInquiryCoreTestsRunner`; it compiles `APIInquiryCore` and the runner executable, nothing else.

- To add a test suite: write a `SomethingTests` type with `static func run(using harness: TestHarness)` (add `async` if it awaits), then register it in the call list in `Sources/APIInquiryCoreTestsRunner/main.swift` — sync suites call `.run(using:)`, async suites `await ...run(using:)`.
- Assert via `harness.expectEqual` / `expectTrue` / `expectThrowsBalanceProviderError`.
- No single-test filter; the runner executes everything and exits non-zero on any failure. Expected output: `PASS: N expectations`.
- Fake keys + mocked network only — never real credentials.

## Branch and worktrees

- Default branch is `main` (not `master`). Do not implement on `main`.
- Implementation happens in isolated git worktrees named after the work, e.g. `.worktrees/issue-13-config-entry/`. Commit per completed task; use TDD for behaviour changes.
- Current work is **issue-driven, not plan-driven**: `docs/superpowers/plans/` stops at v0.3.15 and is historical; issues live in GitHub Issues.
- Repository layout, and where new files belong: `docs/repository-layout.md` (pair: `_zh.md`).

## Architecture gotchas (see the code, or the local `CLAUDE.md`, for full detail)

- `APIInquiryCore` is the only library target and holds the testable logic; `APIInquiryApp` (SwiftUI + AppKit) and `APIInquiryCoreTestsRunner` are executables on top of it. Keep testable logic in Core.
- **Codex manual-reset credits are a parallel subsystem, not a `BalanceProvider`.** Don't try to fit credits data into `ProviderSnapshot` — see `CodexManualResetCreditsProvider` / its own protocol.
- `BuiltInProviderRegistry.default` is the single source of truth wiring `ProviderID` → `ProviderDescriptor` + `makeProvider`. Adding a provider touches this chain, and the compiler points at the per-provider switches.
- Credential stores are decorators composed in `APIInquiryApp.init`: `OpenCodeCredentialStore` → `CodexCredentialStore` → `KeychainCredentialStore`. Reads prefer the CLI's own source, read-only (Codex `$CODEX_HOME/auth.json` or `~/.codex/auth.json`; OpenCode `~/.local/share/opencode/opencode.db`), then fall back to the Keychain. Writes go only to the Keychain, and the Console offers save/delete only for `.appManagedAPIKey` providers (DeepSeek, Zhipu); Codex and OpenCode are `.localExternalConfiguration`, so their credentials belong to the CLI and the app never rewrites them. A decorator must forward everything it does not override.
- `LocalConfigurationProviding` backs the API page's 打开配置 button: the store answers which local file represents the provider (`nil` disables the button and shows a hint). Add a new provider's path there, not as an `if id == .codex` in the view.

## Conventions

- **Security**: never commit/log/print/display a real API key, Codex access token, session token, or account id. After a key is saved, UI shows only configured/replace/delete states.
- **Bilingual docs**: substantial planning/spec/README docs are paired — English `<name>.md` and Chinese `<name>_zh.md`. Any change to one must be synced to the other. See `docs/superpowers/documentation-conventions.md`.
- **User conversation is usually in Chinese**; prefer asking the user to review the Chinese doc version.
- **Triage labels**: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
- **Releases**: bump `Scripts/version.env` so APP_VERSION, BUILD_NUMBER, RELEASE_TAG, DMG_BASENAME, VOLUME_NAME all match; verify the built app's `CFBundleShortVersionString`. Release notes are user-facing copy grouped into New Features / App Optimization / Bug Fixes (omit empty sections) — describe perceptible impact, not internal type names or file paths.
