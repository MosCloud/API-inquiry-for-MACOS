# API Inquiry Settings Page Optimization Notes

## Summary

The Settings page should become API Inquiry's app-level control center, but it should not become a miscellaneous provider-management drawer. It should stay restrained and only own preferences, release information, security and privacy notes, diagnostics, and future advanced capabilities that affect the whole app. Provider setup, display strategy, credential management, and individual provider status should remain owned by Home, API, and the menu bar detail panel.

## Current State

The current Settings page only contains language selection, the app version, and a project homepage action. That scope is lightweight, but the information architecture is still temporary: existing content is not clearly grouped, and there is no stable space yet for future notifications, updates, security, privacy, diagnostics, or advanced app-level controls.

## Page Responsibility

Settings should own app-level preferences and information:

- Global preferences, such as language, launch at login, refresh interval, and menu bar display format.
- Notifications and reminders, such as low balance, low quota, and threshold preferences.
- Security and privacy notes, such as credential storage, local configuration behavior, and a statement that local credentials are not uploaded.
- Update and release information, such as current version, check for updates, release notes, and project homepage.
- Diagnostics and maintenance, such as exporting redacted diagnostics, opening a log directory, and resetting app preferences.
- Advanced and experimental capabilities, such as future custom providers or debug toggles.

Settings should not own provider-level management:

- Adding or removing providers should remain in Home or API.
- Primary Provider / menu bar display target should remain in Home.
- Replacing API keys and opening OpenAI/Codex local configuration should remain in API.
- Individual provider balance, quota, and refresh status should remain in Home or the menu bar detail panel.

## Possible Settings

### General

- Language: `Auto / 中文 / English`.
- Launch at login: currently in the menu bar detail footer; it can have a formal place in Settings later.
- Refresh interval: future options such as `5 / 10 / 15` minutes.
- Menu bar display format: icon only, icon plus amount, or icon plus status.

### Notifications And Reminders

- Low balance reminder toggle.
- Low quota reminder toggle.
- Balance or quota threshold settings.

These features fit future versions, but they should be designed carefully so API Inquiry does not become a complex alerting system.

### Security And Privacy

- Briefly explain that API keys are stored in macOS Keychain.
- Explain that local configuration and auth files are not uploaded.
- Provide actions for opening Keychain Access or relevant local configuration locations.
- Provide a note or link for release-time privacy packaging audits.

This section should be built around "status/explanation plus management actions", not long repeated messaging.

### Updates And Releases

- Current app version.
- Check for updates, for the future v0.5.0 auto-update path.
- Release notes.
- GitHub project homepage.
- Known limitations, such as Apple notarization not being enabled yet.

### Diagnostics

- Export redacted diagnostics.
- Open log directory.
- Reset app preferences.

Diagnostics should live near the bottom or in an advanced area to reduce accidental use. Any exported content must exclude API keys, tokens, Keychain contents, and local auth files.

### Advanced

- Provider debug toggles.
- Custom provider or endpoint entry points.
- Experimental feature toggles.

Advanced capabilities should come after the basic Settings information architecture is stable.

## Recommended First Optimization Scope

The next Settings page optimization should focus on information architecture and visual structure before adding complex new features:

- Keep the existing language selection.
- Keep the app version and project homepage.
- Add a Security and Privacy section.
- Add an About or Release Information section.
- Reserve structure for future notifications, updates, and diagnostics without implementing all of them immediately.

The first goal is to build a clean framework so future features have a natural place, not to put every possible setting into the page at once.

## Visual Direction

Settings should feel like a compact macOS Settings-style grouped list, not a pile of large cards or a marketing page:

- Use compact groups, such as General, Security and Privacy, and About.
- Use row-based layout inside each group: title and optional helper text on the left, control on the right.
- Prefer system-like controls: segmented picker, toggle, button, and menu.
- Keep more space between groups and tighter row height inside groups.
- Avoid long explanatory text and avoid repeating baseline security principles as promotional copy.
- Keep the overall surface quiet, scannable, and low-decoration.

## Design Principles

- The menu bar detail panel only owns status viewing and lightweight actions.
- Console Home owns provider overview and menu bar display strategy.
- Console API owns credentials, local configuration, and provider access management.
- Console Settings owns app-level preferences, release information, security/privacy, and diagnostics.
- When flexibility conflicts with product clarity, prefer clear boundaries and restrained interaction.
