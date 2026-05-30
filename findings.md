# Current Findings

## Repository State

- Current branch/worktree: `v0.3.7` at `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.7`.
- Branch base: current `main` commit `c6b521c` (`docs: reduce README screenshot sizes`).
- Latest released version remains `v0.3.6-Refactor`.
- `v0.3.7` is planned as a UI polish release before the `v0.4.0` provider expansion.
- The main worktree still has an untracked `.superpowers/` directory that should not be touched unless explicitly requested.

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

## v0.3.7 UI Planning Findings

- The UI style direction must stay minimal, restrained, efficient, lightly technical, and content-first.
- Microinteractions are acceptable only when they make loading, errors, state changes, or value changes easier to understand.
- Decorative visual treatments should be rejected if they compete with quota, provider, or credential content.
- `MenuBarContentView` is still a maintenance target and should be split without changing behavior first.
- API access UI should avoid localized string comparison and prefer explicit display state.
- macOS deployment target is still macOS 13+, so macOS 14-only numeric text transitions require availability-gated fallback.
- `v0.3.7` should not add providers, redesign credential storage, or move into v0.4.0 generic provider work.

## Important Docs And Plans

- v0.3.7 UI polish plan:
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish_zh.md`
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

- Roadmap next planned version: `v0.3.7`.
- v0.3.7 focus:
  - restrained UI motion and state feedback
  - UI semantic robustness
  - color/accessibility polish
  - `MenuBarContentView` splitting
  - light Console Home/API interaction improvements
- v0.4.0 remains focused on:
  - more built-in providers
  - more generic provider capabilities
  - provider ordering/hiding/enabling policy
  - validation that adding a mock built-in provider does not require UI branching
- Keep custom/dynamic provider IDs out of scope until there is a clearer migration need.
