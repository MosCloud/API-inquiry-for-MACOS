# DeepSeek Menu Bar Balance Monitor Design

## Summary

Build a native macOS menu bar app named API Inquiry. The first release focuses on one job: use DeepSeek's official API to query the account balance and keep that balance visible in the macOS menu bar.

The menu bar label uses a dynamically rendered DeepSeek template image plus compact balance text such as `¥68.6`. The expanded panel shows a minimal DeepSeek balance view headed by an adaptive monochrome DeepSeek logo, with manual refresh, status, last refresh time, API key settings, an external console link, and quit. The installed `.app` includes a custom Apple-style application icon generated from local assets and bundled as `AppIcon.icns`. Detailed usage charts, local DeepSeek console features, and multi-provider UI are intentionally deferred.

## Goals

- Show DeepSeek account balance directly in the macOS menu bar.
- Refresh balance automatically every 5 minutes and manually on demand.
- Store the DeepSeek API key securely in macOS Keychain.
- Keep the expanded panel minimal and calm, with no first-release charts.
- Use a provider abstraction so future API providers can be added without rewriting the UI.
- Deliver source code that runs locally on the user's machine before considering app packaging, signing, or distribution.

## Non-Goals

- Do not build monthly usage charts in the first release.
- Do not scrape or automate the DeepSeek web console in the first release.
- Do not show topped-up balance or granted balance in the UI yet, even though the API model can retain those fields.
- Do not support multiple providers in the UI yet.
- Do not build a local DeepSeek console yet.
- Do not notarize or distribute the app in the first release; local ad-hoc `.app` packaging is included.

## Platform And Technology

- Platform: macOS 13 Ventura and later.
- App type: native macOS menu bar app.
- UI: SwiftUI with `MenuBarExtra`.
- Networking: `URLSession`.
- Secure storage: macOS Keychain.
- Data source: DeepSeek official API endpoint `GET https://api.deepseek.com/user/balance`.

## DeepSeek API Scope

DeepSeek's public documentation exposes `GET /user/balance`, which returns:

- `is_available`
- `balance_infos[].currency`
- `balance_infos[].total_balance`
- `balance_infos[].granted_balance`
- `balance_infos[].topped_up_balance`

The first release uses only:

- `is_available`
- preferred balance info for `CNY`, falling back to the first returned balance record
- `total_balance`
- `currency`

The app keeps `granted_balance` and `topped_up_balance` in the parsing model for future use, but does not show them in the first-release UI.

DeepSeek's public FAQ describes detailed API key usage as a Usage page export flow that downloads CSV files. Because there is no clearly documented public API endpoint for detailed monthly usage, first release does not attempt automatic usage-chart refresh.

## User Experience

### First Launch

If no DeepSeek API key is stored, the menu bar item should use a compact unconfigured state such as the DeepSeek icon plus `Setup`.

Opening the menu shows a focused setup panel:

- DeepSeek title
- secure text field for the API key
- save button
- short status message if validation or saving fails

The API key is visible only while the user is typing it. After saving, the normal UI never shows the key in plain text. When a key is configured, the API key row is collapsed by default and shows only the configured state plus an expand control; expanding the row reveals the replacement field, Replace, and Delete controls.

### Normal Menu Bar Title

The base menu bar label format is:

```text
[DeepSeek icon] ¥68.6
```

Rules:

- Use a dynamically rendered monochrome template DeepSeek image in place of the `DS` text prefix.
- Size the menu bar icon larger than the amount text, following common macOS status item proportions, and render the amount text at regular weight so the label stays visually light.
- Use the currency symbol for CNY when possible.
- Show one decimal place in the menu bar to save space.
- Keep the last successful balance visible if a later refresh fails.
- If the app has no successful balance yet, show the DeepSeek icon plus `--`.

The textual `DS` fallback remains available in the view model for tests and accessibility, while the app label uses the icon-first display.

### Expanded Panel

The expanded panel should be extremely minimal:

- DeepSeek logo image rendered as a template so it adapts to light and dark appearance
- compact top logo sizing so the balance remains the visual focus
- large balance value, such as `¥68.65 CNY`, with the numeric amount clearly dominant at medium weight and the currency symbol/code smaller at regular weight
- small status line:
  - available
  - balance insufficient
  - not configured
  - refreshing
  - refresh failed
- last successful refresh time
- refresh button placed where it is easy to reach but visually quiet
- secondary actions:
  - open DeepSeek console at `https://platform.deepseek.com/usage`
  - set or replace API key
  - delete API key
  - quit

Do not show 充值余额 or 赠金余额 in this first-release panel.

### App Bundle Icon

The packaged app uses a custom macOS icon rather than the default executable icon.

Rules:

- Generate the icon through `Scripts/generate-app-icon.swift` so the source asset, preview PNG, and `.icns` stay reproducible.
- Use a rounded blue macOS-style base, a clean DeepSeek symbol, and a small usage-bars mark to connect the icon to API balance monitoring.
- Preserve the DeepSeek symbol's source aspect ratio when drawing it into the icon; do not force it into a square frame.
- Bundle `Sources/APIInquiryApp/Resources/AppIcon.icns` and set `CFBundleIconFile` / `CFBundleIconName` to `AppIcon`.

## Architecture

### Provider Abstraction

Define a provider boundary so DeepSeek is the first provider, not a hard-coded special case throughout the app.

Core concepts:

- `BalanceProvider`
  - provider id
  - display name
  - short menu prefix
  - credential key name
  - balance fetch function
- `BalanceSnapshot`
  - provider id
  - total balance
  - currency
  - availability status
  - optional granted balance
  - optional topped-up balance
  - fetched-at timestamp
- `BalanceState`
  - not configured
  - loading
  - loaded snapshot
  - failed with last known snapshot
  - failed without snapshot

The first release ships one concrete provider: `DeepSeekBalanceProvider`.

### App Services

- `DeepSeekBalanceProvider`
  - builds the `/user/balance` request
  - attaches `Authorization: Bearer <api key>`
  - decodes the response
  - maps API errors into user-friendly states
- `KeychainCredentialStore`
  - saves, loads, replaces, and deletes API keys
  - never logs secret values
- `BalanceRefreshController`
  - triggers refresh on launch, manual tap, and 5-minute timer
  - avoids overlapping refresh requests
  - preserves the last successful snapshot on failures
- `MenuBarBalanceViewModel`
  - formats menu bar label
  - exposes panel state
  - coordinates settings actions and refresh commands

### UI Components

- `APIInquiryApp`
  - app entry point
  - owns `MenuBarExtra`
- `MenuBarContentView`
  - compact expanded panel
  - switches between setup state and balance state
- `APIKeySettingsView`
  - input-only view for first save or replacement
  - after save, shows a collapsed configured row by default
  - expanding the configured row reveals replace and delete affordances

## Data Flow

1. App starts.
2. View model asks `KeychainCredentialStore` for the DeepSeek API key.
3. If missing, menu bar shows setup state.
4. If present, app immediately refreshes balance.
5. `DeepSeekBalanceProvider` sends `GET https://api.deepseek.com/user/balance`.
6. Response is decoded into `BalanceSnapshot`.
7. View model updates the menu bar label and expanded panel.
8. A 5-minute timer repeats refresh while the app is running.
9. Manual refresh uses the same refresh path.
10. Failed refresh keeps the last successful balance visible and surfaces the error in the expanded panel.

## Error Handling

- Missing key: show setup state.
- Invalid key or authentication failure: show a clear "API key may be invalid" message and offer replace/delete.
- Insufficient balance response: show balance plus unavailable status.
- Network failure: keep last successful value if present; otherwise show the DeepSeek icon plus `--`.
- Non-JSON or schema mismatch: show refresh failed and preserve last successful value.
- Rate limit or server error: show refresh failed with a short retry-oriented message.

Errors must not include the API key, authorization header, or any other secret.

## Security Requirements

- Store API key only in macOS Keychain.
- Do not persist the API key in UserDefaults, logs, snapshots, crash messages, or plaintext files.
- Show the API key only while the user is entering or replacing it.
- After save, UI only shows a collapsed configured state until the user expands the API key row.
- Tests must use fake keys and must not require a real DeepSeek account.

## Testing Plan

### Unit Tests

- Decode a successful DeepSeek balance response.
- Prefer CNY balance when multiple currencies are returned.
- Fall back to the first balance when CNY is absent.
- Format menu bar label as DeepSeek icon plus `¥68.6`.
- Format full panel balance as `¥68.65 CNY`.
- Preserve last successful snapshot when refresh fails.
- Map missing key, invalid key, insufficient balance, network failure, and server failure into correct UI states.
- Verify provider abstraction can fetch through a mock provider without DeepSeek-specific UI coupling.

### Keychain Tests

- Save a fake API key.
- Load the fake API key.
- Replace the fake API key.
- Delete the fake API key.
- Confirm UI-facing state never returns the full saved key for display.

### Integration Tests

- Use a mocked `URLProtocol` or injectable HTTP client to simulate DeepSeek responses.
- Verify automatic refresh can be triggered through the refresh controller without waiting 5 real minutes.
- Verify manual refresh and automatic refresh use the same code path.

### Manual Tests

- Launch with no API key.
- Save a real API key locally.
- Confirm menu bar changes from setup state to balance state.
- Click refresh and confirm updated status.
- Disconnect network and confirm last successful balance remains visible.
- Delete API key and confirm the setup state returns.
- Open DeepSeek console link.
- Quit from the menu.

## Future Extensions

- Add local DeepSeek usage console after first release is stable.
- Support CSV import from DeepSeek's Usage export.
- Add UI for monthly spend, request count, and token charts when a stable data source is available.
- Add additional providers behind the existing provider abstraction.
- Add optional icon plus balance menu-bar display.
- Add Developer ID signing, notarization, and distribution.

## References

- DeepSeek balance API: `https://api-docs.deepseek.com/zh-cn/api/get-user-balance`
- DeepSeek usage export FAQ: `https://api-docs.deepseek.com/faq`

## Open Decisions Resolved

- Product form: macOS menu bar app.
- First-release provider: DeepSeek only.
- First-release data: balance only.
- Refresh cadence: every 5 minutes plus manual refresh.
- API key storage: macOS Keychain only.
- Minimum OS: macOS 13 Ventura.
- Tech stack: Swift and SwiftUI.
- First deliverable: local runnable source project.
