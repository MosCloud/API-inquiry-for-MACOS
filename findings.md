# Current Findings

## Repository State

- Current branch/worktree: `v0.3.7` at `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.7`.
- Branch base: current `main` commit `c6b521c` (`docs: reduce README screenshot sizes`).
- `v0.3.7` is the active release candidate for formal publication.
- `v0.3.7` remains a UI polish release before the `v0.4.0` provider expansion.
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

## v0.3.7 Round 1 UI Polish Findings

- Round 1 implementation is intentionally narrow:
  - `APIAccessBadge` now uses explicit `APIAccessState` from `APIProviderSummary` instead of comparing localized status text.
  - API access state tests cover configured managed API keys, loaded Codex external config, unconfigured managed keys, unloaded Codex config, and Chinese copy with stable state.
  - Added short localized helper strings for `More Actions`, `Current Status`, and `Quota Window`.
  - The API provider more menu now exposes neutral "More Actions" help/accessibility text while keeping the destructive menu item text unchanged.
  - Menu bar icon buttons, status row, quota hero rows, provider rows, badges, and feedback text received small accessibility/microinteraction polish.
  - Warning amount color is centralized through a quieter shared amber token.
- QA review findings were addressed:
  - Refresh button accessibility label stays action-oriented (`Refresh`/`刷新`) while refreshing state is exposed through accessibility value.
  - Refresh loading motion is a subtle repeated 360-degree rotation while refreshing, not a one-time half-turn.
  - Quota row accessibility combines amount and suffix into values such as `72%` instead of separate fragments.
- Deferred by design for later v0.3.7 review:
  - `MenuBarContentView` component splitting
  - Console Home layout/density changes
  - API removal confirmation popover/sheet changes
  - provider expansion and generic v0.4.0 provider capabilities
  - `NSImage.lockFocus` replacement or other logo drawing changes

## v0.3.7 Round 2 Versioned UI Effects Findings

- Round 2 is scoped to higher-version SwiftUI progressive enhancement while keeping macOS 13+ as the supported fallback.
- Higher-version effects should be centralized in an App-target helper rather than scattered through business views.
- `ContentTransition.numericText(value:)` is macOS 14+ and should only be used when a real numeric value is available; formatted display strings such as amount text should not be parsed just to drive the transition.
- The safe fallback for display-only numeric text is explicit `ContentTransition.numericText(countsDown: false)`, available on macOS 13+.
- `symbolEffect` is macOS 14+; `.rotate` is macOS 15+, while lighter options such as `.variableColor` are available on macOS 14.
- `sensoryFeedback` is macOS 14+ and should be applied only to concrete result feedback, not hover, navigation, or ordinary state color changes.
- `glassEffect` is macOS 26+ and remains out of scope for v0.3.7.

## v0.3.7 Round 3 Perceptible Versioned UI Effects Findings

- The current Round 2 numeric transition is visually subtle because `MenuBarContentView` passes `nil` to `apiInquiryNumericTextTransition(value:)`; macOS 14+ `numericText(value:)` is not used for the primary amount or quota amount yet.
- Core snapshot data already contains raw `Decimal` values for balance totals, plan usage percentage, and quota remaining percentage, so the safe path is to expose numeric display values from display models instead of parsing formatted strings in App views.
- Refresh symbol effects can be missed because refresh often completes quickly; the first Round 3 visual hold also exposed a timing mismatch because the hold duration did not control the system symbol effect's own cycle duration.
- Settings/result feedback is currently text-only plus sensory feedback; a small tone-colored status icon can make success/warning/error easier to scan without introducing toast, modal, or decorative treatment.
- Round 3 implementation exposed `amountValue` from real snapshot decimals, activated macOS 14+ `numericText(value:)` call sites, replaced refresh active/hold animation with a deterministic 0.8s forward-only refresh turn loop that respects Reduce Motion, and added inline feedback icons hidden from VoiceOver.
- QA first found a visual hold cleanup issue; that intermediate hold-based implementation is now removed entirely.
- User review found the active/hold refresh animation could stutter or visually return near the end of a turn. The root cause was using an active boolean to drive system/fallback rotation and then deactivating it independently of the actual rotation cycle. The fix uses cumulative turn counts so each tap advances from the current angle to the next 360-degree target without animating back to zero; if real refresh remains in progress, the loop advances one more turn every 0.8s until loading ends.
- Release QA found two accessibility/motion gaps before publication: non-refresh UI motion did not fully honor Reduce Motion, and the Console Home provider row could flatten child controls into an incomplete row label. These were fixed by centralizing motion helpers, passing Reduce Motion into numeric/top-change/subtle animations, and preserving child accessibility for provider row controls.
- Release notes now follow the repository release section convention with `App Optimization` and `Bug Fixes`.
- `README_zh.md` was still on v0.3.6 release artifact names and `PASS: 341 expectations`; it is now synchronized with the v0.3.7 README state.

## Important Docs And Plans

- v0.3.7 UI polish plan:
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish_zh.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish-round1.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-ui-polish-round1_zh.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-versioned-ui-effects.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-versioned-ui-effects_zh.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-perceptible-versioned-ui-effects.md`
  - `docs/superpowers/plans/2026-05-30-v0.3.7-perceptible-versioned-ui-effects_zh.md`
- Release notes:
  - `docs/releases/v0.3.7.md`
  - `docs/releases/v0.3.7_zh.md`
  - `docs/releases/v0.3.7_github.md`
  - `docs/releases/v0.3.6-refactor.md`
  - `docs/releases/v0.3.6-refactor_zh.md`
  - `docs/releases/v0.3.6-refactor_github.md`
- Architecture/refactor plans:
  - `docs/superpowers/plans/2026-05-29-v0.3.6-refactor-architecture.md`
  - `docs/superpowers/plans/2026-05-29-v0.3.6-refactor-architecture_zh.md`
  - `docs/superpowers/plans/2026-05-30-provider-registration-runtime-refactor.md`
  - `docs/superpowers/plans/2026-05-30-provider-registration-runtime-refactor_zh.md`
- Exploration prompts:
  - `docs/superpowers/specs/2026-05-30-v0.3.7-liquid-glass-ui-exploration-prompt.md`
  - `docs/superpowers/specs/2026-05-30-v0.3.7-liquid-glass-ui-exploration-prompt_zh.md`
- README screenshots now live in:
  - `docs/assets/v0.3.6-refactor/menu-bar.png`
  - `docs/assets/v0.3.6-refactor/console-home.png`
  - `docs/assets/v0.3.6-refactor/console-api.png`
  - `docs/assets/v0.3.6-refactor/console-setting.png`

## Verification Evidence

- During v0.3.7 Round 3 perceptible versioned UI effects:
  - `git diff --check` passed.
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 507 expectations`.
  - `swift build` passed.
  - QA agent re-review found no Critical or Important blocking issues after the initial refresh visual hold cleanup fix.
  - A later user-reported refresh animation issue was fixed by replacing active/hold rotation with deterministic one-turn rotation.
  - `Scripts/run-local-app.sh` built and started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.7/.build/APIInquiry.app`.
- During v0.3.7 release candidate verification:
  - `git diff --check` passed.
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 507 expectations`.
  - `swift build` passed.
  - `Scripts/run-local-app.sh` built and started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.7/.build/APIInquiry.app`.
  - `Scripts/package-dmg.sh` produced `dist/API-Inquiry-v0.3.7.dmg` and `dist/API-Inquiry-v0.3.7.dmg.sha256`.
  - `CFBundleShortVersionString` is `0.3.7`.
  - `CFBundleVersion` is `12`.
  - `codesign --verify --deep "dist/API Inquiry.app"` passed.
  - `hdiutil verify dist/API-Inquiry-v0.3.7.dmg` passed.
  - `(cd dist && shasum -a 256 -c API-Inquiry-v0.3.7.dmg.sha256)` passed.
  - DMG SHA-256 is `91ac2cd7e1a528ab88c5e2c38cc3b984b84b025c610eb40f22cb462d329fa6fb`.
- During v0.3.7 Round 2 versioned UI effects:
  - `git diff --check` passed.
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 493 expectations`.
  - `swift build` passed.
  - QA agent review found no Critical or Important blocking issues after the documentation wording fix.
  - `Scripts/run-local-app.sh` built and started `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.7/.build/APIInquiry.app`.
- During v0.3.7 Round 1 UI polish:
  - `swift run APIInquiryCoreTestsRunner` passed with `PASS: 493 expectations`.
  - `swift build` passed.
  - Code quality QA agent re-review found no remaining Critical, Important, or Minor blocking issues after refresh-button accessibility/motion and quota accessibility fixes.
- After the registration runtime refactor: `swift run APIInquiryCoreTestsRunner` passed with `PASS: 478 expectations`.
- After merging `v0.3.6-Refactor` back to `main`: `swift run APIInquiryCoreTestsRunner` passed with `PASS: 478 expectations`.
- Release packaging for `v0.3.6-Refactor` produced `API-Inquiry-v0.3.6-Refactor.dmg`.
- DMG verification passed with `hdiutil verify`.
- DMG checksum:
  - `078f1f119ec3ac34283c20ffe4f7c115e8903200d76785453deeda915a2e04cb`

## Next Direction

- Roadmap next planned version after v0.3.7 is `v0.4.0`.
- v0.4.0 remains focused on:
  - more built-in providers
  - more generic provider capabilities
  - provider ordering/hiding/enabling policy
  - validation that adding a mock built-in provider does not require UI branching
- Keep custom/dynamic provider IDs out of scope until there is a clearer migration need.
