# v0.3.2 Findings

## Repository State

- Current branch: `v0.3.2`, tracking `origin/v0.3.2`.
- `main` and `origin/main` currently point to `1c101612bdb1d3ace75ed5ad0aafcbb42dfefcb5`.
- Latest released version in roadmap: `v0.3.1`.
- Next planned version in roadmap: `v0.3.2`.

## Project Shape

- Swift Package Manager project targeting macOS 13+.
- Main products:
  - `APIInquiryCore`
  - `APIInquiryCoreTestsRunner`
  - `APIInquiryApp`
- Existing verification commands:
  - `swift run APIInquiryCoreTestsRunner`
  - `swift build`
  - `swift Scripts/generate-app-icon.swift`
  - `Scripts/build-local-app.sh`
  - `Scripts/package-dmg.sh`

## v0.3.2 Scope From Roadmap

- Default language mode is `Auto`.
- `Auto` resolves Chinese UI when the macOS preferred language is Chinese; otherwise English.
- Manual language choices: `Auto / 中文 / English`.
- Manual language choice must persist.
- Language switching should update menu details and Console without app restart where practical.
- Localize menu details, Console Home, Console API, buttons, statuses, errors, and settings feedback.
- Preserve provider brand names: `DeepSeek`, `Zhipu GLM Coding Plan`, `OpenAI/Codex`.

## Code Hotspots

- Core display strings:
  - `Sources/APIInquiryCore/Formatting/ProviderDisplayFormatter.swift`
  - `Sources/APIInquiryCore/Formatting/LastRefreshTimeFormatter.swift`
  - `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
  - `Sources/APIInquiryCore/ViewModels/UsageConsoleViewModel.swift`
  - `Sources/APIInquiryCore/Providers/BalanceProvider.swift`
  - `Sources/APIInquiryCore/Models/AutoStartModels.swift`
- SwiftUI hardcoded strings:
  - `Sources/APIInquiryApp/MenuBarContentView.swift`
  - `Sources/APIInquiryApp/UsageConsoleView.swift`
  - `Sources/APIInquiryApp/UsageConsoleWindowController.swift`
  - `Sources/APIInquiryApp/APIInquiryApp.swift`
  - `Sources/APIInquiryApp/LaunchAtLoginController.swift`
- Tests to expand:
  - `Sources/APIInquiryCoreTestsRunner/LastRefreshTimeFormatterTests.swift`
  - `Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`
  - `Sources/APIInquiryCoreTestsRunner/UsageConsoleViewModelTests.swift`
  - New localization tests.

## Planning Notes

- A lightweight localization layer is more compatible with the current Core/ViewModel-heavy architecture than moving all strings into SwiftUI `LocalizedStringKey`.
- Core tests can cover most language behavior without launching the app.
- SwiftUI should mostly receive localized strings from ViewModels or a small observable language store.

## Localization Decisions

- Fixed provider/product names should remain unchanged, including `OpenAI`, `DeepSeek`, and `Zhipu GLM Coding Plan`.
- Common symbols, abbreviations, and plan labels should remain unchanged, including `CNY`, `API`, and `Prolite`.
- `API Key` should be localized as `API 密钥`.
- `Keychain` should be localized as `密钥串`.
- `Keychain Access` should be localized as `密钥串访问` if it appears in user-facing UI.
- Placeholder-based provider guidance should use `{供应商}` in Chinese copy, e.g. `添加 {供应商} API 密钥以开始查询余额。`.
- `Last updated` should be localized as `最近更新`.
- Quota window labels should be localized in Chinese UI: `5h` -> `5 时`, `7d` -> `1 周`.
- Chinese localization should focus on user-facing action text, statuses, guidance, errors, settings feedback, section titles, and time/reset labels.
