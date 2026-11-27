# Third-party notices

This project is MIT licensed (see `LICENSE`). The assets and names below belong to other
parties and are used only to identify the providers this app connects to.

## Brand assets

- **OpenCode** — the header lockup is composed from the official mark and wordmark in the
  OpenCode repository, used under the MIT license, © 2025 opencode.
- **DeepSeek**, **Zhipu (智谱)**, **OpenAI / ChatGPT** — the wordmarks and marks are trademarks
  of their respective owners. They are used here solely to identify the service a provider
  row refers to. Their presence does not imply any affiliation with, endorsement by, or
  sponsorship from those companies.
- **Antigravity** — the mark is the glyph Google ships in Antigravity's own tray template,
  redrawn at higher resolution from the alpha channel of the app icon bundled in
  `Antigravity.app` (2.35.2). It is used here solely to identify the service this provider
  reads, the same way the other marks are. © Google; the app name is Google's trademark, and
  its presence does not imply any affiliation with, endorsement by, or sponsorship from Google.
- The app icon is original artwork created for this project.

## No credential access

The app never uploads, stores or logs provider credentials beyond the local store the user
already trusts: the macOS Keychain for app-managed providers, and the provider's own CLI
files and databases (read-only) for locally configured ones.

## Dependencies

The app links only Apple system frameworks (SwiftUI, AppKit, Security, SQLite). There are no
third-party Swift package dependencies.
