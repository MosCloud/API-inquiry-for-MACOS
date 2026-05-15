# API Inquiry

API Inquiry is a native macOS menu bar app for checking a DeepSeek API account balance. The first release is intentionally minimal: it stores one DeepSeek API key in macOS Keychain, refreshes the official balance API every 5 minutes, supports manual refresh, and shows the current balance in the menu bar.

## Requirements

- macOS 13 or later
- Swift 5.9+ / Xcode Command Line Tools
- A DeepSeek API key for real balance checks

## Security

- The API key is stored only in macOS Keychain through `KeychainCredentialStore`.
- The saved key is never shown in plain text after saving. The UI shows `Configured` by default; the input field, `Replace`, and `Delete` controls appear only after expanding the API key row.
- Tests use fake keys only and do not require a real DeepSeek account.
- Do not put real API keys in source files, docs, logs, screenshots, or shell history.

## Test

This project uses a local executable runner because this development machine has Command Line Tools but not a full XCTest runtime.

```bash
swift run APIInquiryCoreTestsRunner
```

Expected result:

```text
PASS: 54 expectations
```

## Build

Compile all package targets:

```bash
swift build
```

Build a local macOS app bundle:

```bash
Scripts/build-local-app.sh
```

The script creates:

```text
.build/APIInquiry.app
```

The generated `Info.plist` sets `LSUIElement=true`, so the app runs as a menu bar accessory app.

## Run Locally

```bash
open .build/APIInquiry.app
```

Manual checks:

- First launch with no key shows setup state.
- Saving a key clears the input field and stores the key in Keychain.
- After a key is configured, the API key row is collapsed until you expand it.
- The menu bar uses a dynamic DeepSeek template label plus compact balance formatting, for example `¥68.6`.
- The menu bar icon is larger than the amount text, matching common macOS status items, while the amount uses regular weight to keep the label light.
- The expanded panel logo adapts automatically to light and dark appearance.
- The panel uses full balance formatting, for example `¥68.65 CNY`, with the logo kept compact, the numeric amount dominant at medium weight, and the currency symbol/code at regular weight.
- Manual refresh uses the same refresh path as automatic refresh.
- Delete removes the key and returns the app to setup state.

## Scope

Included in this release:

- DeepSeek balance API integration
- Secure Keychain storage
- 5-minute automatic refresh and manual refresh
- Minimal native `MenuBarExtra` UI
- Local `.app` bundle generation

Deferred:

- Detailed usage charts
- Local DeepSeek usage console
- Multi-provider UI
