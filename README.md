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
PASS: 71 expectations
```

## Build

Compile all package targets:

```bash
swift build
```

Regenerate the bundled macOS app icon:

```bash
swift Scripts/generate-app-icon.swift
```

Build a local macOS app bundle:

```bash
Scripts/build-local-app.sh
```

The script creates:

```text
.build/APIInquiry.app
```

The app sets its accessory activation policy at launch, so it runs as a menu bar utility while remaining visible in installer DMGs.
The build scripts regenerate and bundle the custom `AppIcon.icns` automatically.

Package a release macOS app bundle:

```bash
Scripts/package-mac-app.sh
```

The script creates and ad-hoc signs:

```text
dist/API Inquiry.app
```

Package a GitHub Release DMG:

```bash
Scripts/package-dmg.sh
```

The script creates:

```text
dist/API-Inquiry-alpha.dmg
```

## Install From GitHub DMG

This project uses a free alpha distribution strategy for GitHub Releases. The DMG is ad-hoc signed but not Apple notarized.

1. Download `API-Inquiry-alpha.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `API Inquiry.app` into `Applications`.
4. Launch API Inquiry from Applications.

If macOS blocks the first launch because the developer cannot be verified:

1. Right-click `API Inquiry.app`.
2. Choose `Open`.
3. Confirm `Open` in the system prompt.

You can also allow the app from `System Settings > Privacy & Security`.

## Run Locally

```bash
open .build/APIInquiry.app
```

Run the packaged release app:

```bash
open "dist/API Inquiry.app"
```

Install the packaged app into your user Applications folder:

```bash
Scripts/install-mac-app.sh
```

Restart the installed app:

```bash
Scripts/restart-installed-app.sh
```

The installed app path is:

```text
~/Applications/API Inquiry.app
```

Manual checks:

- First launch with no key shows setup state.
- Saving a key clears the input field and stores the key in Keychain.
- After a key is configured, the API key row is collapsed until you expand it.
- The menu bar uses a dynamic DeepSeek template label plus compact balance formatting, for example `¥68.6`.
- The menu bar icon is larger than the amount text, matching common macOS status items, while the amount uses regular weight to keep the label light.
- The expanded panel logo adapts automatically to light and dark appearance.
- The panel uses full balance formatting, for example `¥68.65 CNY`, with a smaller header logo, the numeric amount dominant at medium weight, and the currency symbol/code smaller at regular weight.
- The installed app uses the custom Apple-style icon from `AppIcon.icns`.
- The footer shows three evenly sized actions: `AutoStart`, `Console`, and `Quit`.
- The `AutoStart` action toggles launch at login and changes color when enabled.
- The last updated time follows the system 12-hour or 24-hour clock setting.
- Manual refresh uses the same refresh path as automatic refresh.
- Delete removes the key and returns the app to setup state.

## Scope

Included in this release:

- DeepSeek balance API integration
- Secure Keychain storage
- 5-minute automatic refresh and manual refresh
- Minimal native `MenuBarExtra` UI
- Local `.app` bundle generation
- Custom macOS app icon generation and bundling
- Launch at login control from the details panel
- Free GitHub DMG packaging without Apple notarization

Deferred:

- Detailed usage charts
- Local DeepSeek usage console
- Multi-provider UI
- Developer ID signing and notarization
