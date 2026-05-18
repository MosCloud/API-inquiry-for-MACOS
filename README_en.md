# API Inquiry

[中文](README.md)

API Inquiry is a native macOS menu bar app for checking API provider status and managing provider API keys. It supports DeepSeek balance checks, Zhipu GLM Coding Plan usage, and Codex/ChatGPT session quota checks, stores provider API keys in macOS Keychain, refreshes configured providers every 5 minutes, shows the Primary Provider in the menu bar, and provides a lightweight local console for provider management.

## Requirements

- macOS 13 or later
- Swift 5.9+ / Xcode Command Line Tools
- A DeepSeek API key for real balance checks, or a Zhipu GLM Coding Plan API key for plan usage checks
- For Codex quota checks, this Mac needs an existing Codex login with `$CODEX_HOME/auth.json` or `~/.codex/auth.json`

## Security

- API keys are stored only in macOS Keychain through `KeychainCredentialStore`.
- The Codex provider first reads the local Codex auth file as read-only state. It does not modify, delete, or copy that file into UserDefaults; Keychain is only a manual fallback.
- Saved keys are never shown in plain text after saving. API key setup, replacement, and deletion happen in the local console.
- Tests use fake keys only and do not require real DeepSeek, Zhipu, or Codex accounts.
- Do not put real API keys, Codex access tokens, session tokens, or account ids in source files, docs, logs, screenshots, or shell history.

## Test

This project uses a local executable runner because this development machine has Command Line Tools but not a full XCTest runtime.

```bash
swift run APIInquiryCoreTestsRunner
```

Expected result:

```text
PASS: 250 expectations
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
dist/API-Inquiry-v0.3.1.dmg
dist/API-Inquiry-v0.3.1.dmg.sha256
```

After release validation and upload, remove local development app bundles so Launchpad only indexes the installed app:

```bash
Scripts/clean-development-apps.sh
```

## Install From GitHub DMG

This project uses a free GitHub Releases distribution strategy. The DMG is ad-hoc signed but not Apple notarized.

1. Download `API-Inquiry-v0.3.1.dmg` and `API-Inquiry-v0.3.1.dmg.sha256` from GitHub Releases.
2. Verify the download:

   ```bash
   shasum -a 256 -c API-Inquiry-v0.3.1.dmg.sha256
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
- The details panel header shows `Console` and refresh as matched icon actions.
- The footer shows two evenly sized actions: `AutoStart` and `Quit`.
- The console Home page shows provider API key status, validation status, and balance.
- The console API page manages configured provider API keys.
- Console provider names open the provider's API page; DeepSeek opens `https://platform.deepseek.com/usage`.
- The `AutoStart` action toggles launch at login and changes color when enabled.
- The last updated time follows the system 12-hour or 24-hour clock setting.
- Manual refresh uses the same refresh path as automatic refresh.
- Deleting the key from the console returns the app to setup state.
- The menu bar shows only the Primary Provider detail: DeepSeek shows compact balance such as `¥68.6`; Zhipu GLM Coding Plan shows usage such as `5h 17%`.
- When Codex is the Primary Provider, the menu bar shows the ChatGPT/GPT mark plus `5h xx%` remaining quota.
- The Codex detail panel shows both 5h and Week remaining quota windows, and Console Home shows the current plan.
- Codex first auto-reads local Codex login state; you do not need to enter an OpenAI Platform API key in the Console.
- The expanded panel shows the Primary Provider in the top hero area and other providers as compact rows.
- The expanded panel refresh action refreshes all added providers.
- Zhipu GLM Coding Plan shows `Resets` in the expanded panel and `Plan Next Resets` in Console Home.
- Console can add Zhipu GLM Coding Plan and Codex, and set a provider as the Primary Provider shown in the menu bar.
- Deleting one provider key from the console does not affect other provider keys or snapshots.

## Scope

Included in this release:

- DeepSeek balance API integration
- Zhipu GLM Coding Plan usage integration
- Codex/ChatGPT session quota checks with 5h and Week remaining quota
- Codex current plan display
- Built-in multi-provider catalog
- Secure per-provider Keychain storage
- 5-minute automatic refresh and manual refresh
- Minimal native `MenuBarExtra` status UI for the Primary Provider
- Local API Inquiry console window
- Local API provider console with Home and API pages
- Provider status summary with API key, validation, balance, and plan usage state
- Plan reset time display for coding-plan providers
- Local `.app` bundle generation
- Custom macOS app icon generation and bundling
- Launch at login control from the details panel
- Free GitHub DMG packaging without Apple notarization

Deferred:

- Historical usage import and charts
- Arbitrary custom providers
- Developer ID signing and notarization
