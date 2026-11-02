# API Inquiry

[English](README_en.md) · [简体中文](README.md)

A native macOS menu bar app for keeping an eye on how much quota you have left across the AI coding services you use. It sits in your menu bar, refreshes every five minutes, and only opens a lightweight console when you need to change something.

Supports **DeepSeek**, **Zhipu GLM Coding Plan**, **Codex**, **OpenCode** and **WorkBuddy**.

## Features

- **Always in the menu bar**: shows your chosen Primary Provider; click it for an overview of every provider.
- **Five providers, each shown honestly**: balances, plan usage and quota windows are not forced through one template.
- **Credentials stay where they belong**: keys this app owns go into the macOS Keychain; Codex, OpenCode and WorkBuddy credentials are owned by their own CLI or desktop app, and this app only reads them.
- **Bilingual**: follows the system language by default, switchable in the Console.
- **No dashboard**: no analytics, no history graphs, no sixth provider invented in a config file.

## Supported providers

| Provider | What you see | Credential source |
|---|---|---|
| **DeepSeek** | Account balance, granted and topped-up shown apart | macOS Keychain |
| **Zhipu GLM Coding Plan** | Plan usage and reset time | macOS Keychain |
| **Codex** | Session quota (5-hour / weekly) | Local Codex sign-in, read-only |
| **OpenCode** | Usage windows (5-hour / weekly / monthly) | Local OpenCode database, read-only |
| **WorkBuddy** | Remaining credits, with next refresh and nearest expiry | Local WorkBuddy desktop sign-in, read-only |

WorkBuddy is currently CN-region only (`www.codebuddy.cn`); the international build is not supported yet.

## Install

Download the latest DMG and checksum from [GitHub Releases](https://github.com/MosCloud/API-inquiry-for-MACOS/releases): `API-Inquiry-vX.Y.Z.dmg` for the Chinese installer, `API-Inquiry-vX.Y.Z-en.dmg` for the English one. They contain the same app; only the install window's language differs.

```bash
shasum -a 256 -c API-Inquiry-vX.Y.Z.dmg.sha256
```

Open the DMG, drag `API Inquiry.app` into Applications, and launch it from there.

**The first launch may be blocked**: this project is not notarized by Apple. Right-click the app and choose Open, or allow it under System Settings → Privacy & Security.

**The first launch asks for Keychain access**: that is the app reading the API keys you saved. Click Always Allow. You will be asked again after every local rebuild, because the ad-hoc signature changes.

## Usage

### Menu bar

Click the item: the Primary Provider fills the top, the other added providers sit in rows below. The refresh button refreshes all of them at once.

### Console

| Page | What it owns |
|---|---|
| **Home** | Which provider goes in the menu bar (Primary Provider), and each provider's status |
| **API** | API keys, credential state, and opening a provider's local config file |
| **Settings** | Launch at login, language, version info |

**Codex, OpenCode and WorkBuddy have no "paste a key" step**: their credentials belong to their own CLI or desktop app, and this app only reads them. To switch accounts, switch them in that tool.

## Development

### Requirements

- macOS 13 or later
- **Xcode** (not just Command Line Tools) — compiling `APIInquiryApp` needs it to resolve the SwiftUI macros
- Core work and the test runner are fine with Command Line Tools alone

### Build

```bash
Scripts/build-local-app.sh      # build .build/APIInquiry.app
Scripts/run-local-app.sh        # build and launch
```

Both scripts pick Xcode's developer directory themselves; you do not need to set `DEVELOPER_DIR`.

If you run `swift build` directly you have to pass it yourself, or you will see a wall of `SwiftUIMacros not found`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```

### Test

This project **does not use XCTest**, and it is not because the machine is missing anything — there is simply no `testTarget` in `Package.swift`. Tests are a plain executable runner:

```bash
swift run APIInquiryCoreTestsRunner
```

A successful run prints:

```text
PASS: N expectations
```

`N` moves as tests are added or removed; take the number from the output. The runner is all-or-nothing and exits non-zero on any failure.

### Verify everything at once

```bash
Scripts/verify.sh
```

Tests plus the app build — the gate before opening a pull request.

### Run a side-by-side development copy

```bash
Scripts/run-dev-app.sh
```

It stages an independent `APIInquiryDevelopment` copy under `/private/tmp` and launches it without touching the copy you are using. The copy has its own preferences domain but shares the same Keychain service.

To view the UI with fake data (no network, no Keychain prompt):

```bash
Scripts/run-dev-app.sh --fixtures multi
```

Quit the copy with `pkill -x APIInquiryDevelopment`.

### Release packaging

```bash
Scripts/package-mac-app.sh    # → dist/API Inquiry.app
Scripts/package-dmg.sh --all  # → dist/API-Inquiry-vX.Y.Z.dmg / -en.dmg, each with a .sha256
```

The version lives in one place, `Scripts/version.env`. Full checklist and failure table: [docs/release-runbook.md](docs/release-runbook.md).

## Documentation

| Document | What it covers |
|---|---|
| [docs/repository-layout.md](docs/repository-layout.md) | Where files belong |
| [docs/provider-onboarding.md](docs/provider-onboarding.md) | How to add a provider |
| [docs/release-runbook.md](docs/release-runbook.md) | Release process and troubleshooting |
| [docs/release-writing.md](docs/release-writing.md) | How to write release notes and the CHANGELOG |
| [CHANGELOG.md](CHANGELOG.md) | Full version history |
| [AGENTS.md](AGENTS.md) | This repository's working agreement (written for agents) |

## Known limitations

- Not notarized by Apple; the first launch needs a manual allow.
- Codex, OpenCode and WorkBuddy usage depends on each tool's own sign-in state; when it expires, sign in there again.
- WorkBuddy is CN-region only.
- Providers are limited to the five built in; custom providers are not supported.

## License

[MIT](LICENSE).

Third-party brand assets and trademark notices are in [THIRD-PARTY.md](THIRD-PARTY.md). The names and marks of DeepSeek, Zhipu, OpenAI, OpenCode and WorkBuddy belong to their respective owners; they are used here only to identify the services this app connects to, and imply no affiliation or endorsement.

## Credits

Thanks to Swift and SwiftUI, to [OpenCode](https://github.com/anomalyco/opencode) (whose public brand assets are MIT), and to everyone who has ever wanted one square of their menu bar to tell them how much quota is left.
