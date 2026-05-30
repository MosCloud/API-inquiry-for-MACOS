# Current Findings

## Repository State

- Current branch: `main`, tracking `origin/main`.
- Current `main` / `origin/main`: synchronized after the README screenshot and planning refresh work.
- Latest released version: `v0.3.6-Refactor`.
- Latest release tag: `release/v0.3.6-Refactor`, pointing to `9947bdee457ed029410651bca1d8d890530df048`.
- Latest released build label shown in Settings: `v0.3.6-Refactor`.
- Latest documentation updates after the release: README screenshots, roadmap latest release labels, and root planning files.
- Untracked local directory intentionally ignored for now: `.superpowers/`.

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

## Current Mainline Capabilities

- Native macOS menu bar app for API provider status.
- Supports DeepSeek prepaid balance, Zhipu GLM Coding Plan usage, and Codex/ChatGPT quota windows.
- Multi-provider Console with Home, API, and Settings sections.
- Primary Provider can be displayed in the menu bar.
- API keys are stored in macOS Keychain; Codex provider reads local Codex auth as read-only state before manual fallback.
- Chinese/English localization with `Auto / 中文 / English` selection.
- Release packaging through ad-hoc signed DMG; Apple notarization is still not enabled.

## Current Architecture Findings

- Provider metadata is centralized in `ProviderDescriptor` and `BuiltInProviderRegistry`.
- `ProviderRegistration` is now the runtime binding between descriptor metadata and provider factory.
- `MultiProviderBalanceCoordinator` is registration-first and no longer falls back through `ProviderCatalog.default` or provider metadata when creating runtimes.
- `BalanceProvider` is metadata-free and only requires:
  - `id`
  - `fetchSnapshot(apiKey:)`
- `BalanceRefreshController` receives `credentialAccount` explicitly from descriptor-owned metadata.
- ViewModels use `MultiProviderBalanceCoordinator` as the production state source; legacy single-provider production paths were removed.
- Provider display formatting is split across value formatting, status formatting, tone resolution, and display models, with `ProviderDisplayFormatter` kept as a facade.
- App-layer provider visuals live in `ProviderVisualCatalog`.
- Console UI has been split from the previous large `UsageConsoleView.swift` into focused sections/components.

## Important Docs And Plans

- Release notes:
  - `docs/releases/v0.3.6-refactor.md`
  - `docs/releases/v0.3.6-refactor_zh.md`
  - `docs/releases/v0.3.6-refactor_github.md`
- Architecture/refactor plans:
  - `docs/superpowers/plans/2026-05-29-v0.3.6-refactor-architecture.md`
  - `docs/superpowers/plans/2026-05-29-v0.3.6-refactor-architecture_zh.md`
  - `docs/superpowers/plans/2026-05-30-provider-registration-runtime-refactor.md`
  - `docs/superpowers/plans/2026-05-30-provider-registration-runtime-refactor_zh.md`
- README screenshots now live in:
  - `docs/assets/v0.3.6-refactor/menu-bar.png`
  - `docs/assets/v0.3.6-refactor/console-home.png`
  - `docs/assets/v0.3.6-refactor/console-api.png`
  - `docs/assets/v0.3.6-refactor/console-setting.png`

## Verification Evidence

- After the registration runtime refactor: `swift run APIInquiryCoreTestsRunner` passed with `PASS: 478 expectations`.
- After merging `v0.3.6-Refactor` back to `main`: `swift run APIInquiryCoreTestsRunner` passed with `PASS: 478 expectations`.
- Release packaging for `v0.3.6-Refactor` produced `API-Inquiry-v0.3.6-Refactor.dmg`.
- DMG verification passed with `hdiutil verify`.
- DMG checksum:
  - `078f1f119ec3ac34283c20ffe4f7c115e8903200d76785453deeda915a2e04cb`

## Next Direction

- Roadmap next planned version: `v0.4.0`.
- Likely v0.4.0 focus:
  - more built-in providers
  - more generic provider capabilities
  - provider ordering/hiding/enabling policy
  - validation that adding a mock built-in provider does not require UI branching
- Keep custom/dynamic provider IDs out of scope until there is a clearer migration need.
