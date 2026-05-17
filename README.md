# API Inquiry

API Inquiry is a native macOS menu bar app for checking a DeepSeek API account balance and managing provider API keys. It stores one DeepSeek API key in macOS Keychain, refreshes the official balance API every 5 minutes, supports manual refresh, shows the current balance in the menu bar, and provides a lightweight local console for provider status and API management.

## Requirements

- macOS 13 or later
- Swift 5.9+ / Xcode Command Line Tools
- A DeepSeek API key for real balance checks

## Security

- The API key is stored only in macOS Keychain through `KeychainCredentialStore`.
- The saved key is never shown in plain text after saving. API key setup, replacement, and deletion happen in the local console.
- Tests use fake keys only and do not require a real DeepSeek account.
- Do not put real API keys in source files, docs, logs, screenshots, or shell history.

## Test

This project uses a local executable runner because this development machine has Command Line Tools but not a full XCTest runtime.

```bash
swift run APIInquiryCoreTestsRunner
```

Expected result:

```text
PASS: 88 expectations
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

Build and start the local macOS app bundle for quick validation:

```bash
Scripts/run-local-app.sh
```

During in-progress development, use this script for fast local validation. Full .app release packaging and DMG generation are reserved for release candidate validation.

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
dist/API-Inquiry-v0.2.0.dmg
dist/API-Inquiry-v0.2.0.dmg.sha256
```

## Install From GitHub DMG

This project uses a free GitHub Releases distribution strategy. The DMG is ad-hoc signed but not Apple notarized.

1. Download `API-Inquiry-v0.2.0.dmg` and `API-Inquiry-v0.2.0.dmg.sha256` from GitHub Releases.
2. Verify the download:

   ```bash
   shasum -a 256 -c API-Inquiry-v0.2.0.dmg.sha256
   ```

3. Open the DMG.
4. Drag `API Inquiry.app` into `Applications`.
5. Launch API Inquiry from Applications.

If macOS blocks the first launch because the developer cannot be verified:

1. Right-click `API Inquiry.app`.
2. Choose `Open`.
3. Confirm `Open` in the system prompt.

You can also allow the app from `System Settings > Privacy & Security`.

## Run Locally

```bash
Scripts/run-local-app.sh
```

Open the existing local app bundle directly:

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
- When no key is configured, the menu bar panel points you to the local console.
- Saving a key from the console clears the input field and stores the key in Keychain.
- After a key is configured, the console shows `Configured` without revealing the saved key.
- The menu bar uses a dynamic DeepSeek template label plus compact balance formatting, for example `¥68.6`.
- The menu bar icon is larger than the amount text, matching common macOS status items, while the amount uses regular weight to keep the label light.
- The expanded panel logo adapts automatically to light and dark appearance.
- The panel uses full balance formatting, for example `¥68.65 CNY`, with a smaller header logo, the numeric amount dominant at medium weight, and the currency symbol/code smaller at regular weight.
- The installed app uses the custom Apple-style icon from `AppIcon.icns`.
- The footer shows three evenly sized actions: `AutoStart`, `Console`, and `Quit`.
- `Console` opens the local API Inquiry console window.
- The console Home page shows provider API key status, validation status, and balance.
- The console API page manages configured provider API keys.
- The `AutoStart` action toggles launch at login and changes color when enabled.
- The last updated time follows the system 12-hour or 24-hour clock setting.
- Manual refresh uses the same refresh path as automatic refresh.
- Deleting the key from the console returns the app to setup state.

## Scope

Included in this release:

- DeepSeek balance API integration
- Secure Keychain storage
- 5-minute automatic refresh and manual refresh
- Minimal native `MenuBarExtra` status UI
- Local API Inquiry console window
- Local API provider console with Home and API pages
- Provider status summary with API key, validation, and balance state
- Local `.app` bundle generation
- Custom macOS app icon generation and bundling
- Launch at login control from the details panel
- Free GitHub DMG packaging without Apple notarization

Deferred:

- Multi-provider UI
- Historical usage import and charts
- Developer ID signing and notarization
