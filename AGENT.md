# Agent Instructions

## Project Context

API Inquiry is a native macOS menu bar app for checking DeepSeek API account balance. The first release is balance-only: show the balance in the menu bar, refresh every 5 minutes, support manual refresh, and store the DeepSeek API key in macOS Keychain.

Read the approved docs before implementation:

- Design spec: `docs/superpowers/specs/2026-05-14-deepseek-menu-bar-balance-design.md`
- Implementation plan: `docs/superpowers/plans/2026-05-14-deepseek-menu-bar-balance.md`
- Documentation convention: `docs/superpowers/documentation-conventions.md`

## Language And Documentation

- User-facing conversation is usually in Chinese.
- Substantial planning documents must be maintained in paired English and Chinese files.
- English source files use `<name>.md`.
- Chinese versions use `<name>_zh.md`.
- Any content change to one version must be synchronized to the other.
- Prefer asking the user to review the Chinese version when the conversation is in Chinese.

## Technical Direction

- Platform: macOS 13 Ventura and later.
- App type: native macOS menu bar app.
- UI: SwiftUI `MenuBarExtra`.
- Core package: Swift Package Manager.
- Networking: `URLSession` behind an injectable HTTP client.
- Secure storage: macOS Keychain.
- Tests: local Swift executable runner `APIInquiryCoreTestsRunner`, with fake API keys only.

## Security Rules

- Never commit, log, print, or display a real DeepSeek API key.
- The key is visible only while the user types or replaces it.
- After saving, UI must only show configured, replace, and delete states.
- Store the key only in macOS Keychain, never in UserDefaults, plaintext files, test fixtures, screenshots, or logs.
- Automated tests must use fake keys and mocked network responses.

## Scope Boundaries

First release includes:

- DeepSeek balance query through `GET https://api.deepseek.com/user/balance`.
- Menu bar label based on a dynamically rendered DeepSeek template image plus compact value such as `¥68.6`.
- Minimal expanded panel with an adaptive monochrome DeepSeek logo, balance, status, last refresh time, refresh button, console link, settings, and quit.
- Provider abstraction for future API providers.
- Local release `.app` packaging under `dist/API Inquiry.app` with ad-hoc signing.

First release excludes:

- Monthly usage charts.
- DeepSeek web console scraping or automation.
- Multi-provider UI.
- Local DeepSeek usage console.
- Developer ID signing, notarization, and external distribution.

## Development Workflow

- Do not implement directly on `master`.
- Use an isolated git worktree for implementation work.
- Follow the implementation plan task by task.
- Use TDD for behavior changes: write the failing test, verify it fails, implement the minimal code, then verify it passes.
- Commit after each completed task.
- After each task, run spec compliance review and code quality review before moving on.
- Before claiming completion, run fresh verification commands and report the actual evidence.

## Local Commands

Expected commands after implementation begins:

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

Launching the app for manual verification may require:

```bash
open .build/APIInquiry.app
```
