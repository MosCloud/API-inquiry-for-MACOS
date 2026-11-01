# Adding a provider

This is for **the first person or agent to add a provider to this app**. By the end you should be able to do the whole job alone: data source, credentials, UI, brand assets, tests and acceptance.

It does not describe each provider's business details (those live in the provider files), and it does not re-teach SwiftUI.

> Changing an existing provider's behaviour? Read that module's comments. You do not need this document.

## 1. Make three decisions first

Before writing code, answer three questions. They decide almost every layer below, and getting them wrong means rework (v0.4.0's `planUsage` split is the cautionary tale).

| Decision | Options | What it decides |
|---|---|---|
| **What it sells** | A prepaid balance, or a subscription plan | Status wording (`可用` vs `计划可用`), Console metrics, menu bar copy |
| **What it returns** | One amount, one quota window, or several quota windows | Snapshot type, hero area, secondary rows, Console detail |
| **Where credentials live** | The user pastes a key (Keychain), or the CLI already stores them | Credential decorator, API page buttons, "open config" entry |

The three enums: `ProviderAccessPurpose`, `ProviderSnapshot`, `ProviderCredentialManagement`.

## 2. Data layer: write the provider

A provider implements `BalanceProvider`:

```swift
public final class ExampleProvider: BalanceProvider {
    public let id: ProviderID = .example

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        var request = URLRequest(url: quotaURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200: return try decode(from: response.data)
        case 401: throw BalanceProviderError.authenticationFailed
        case 403: throw BalanceProviderError.subscriptionRequired   // only if it really is subscription-only
        case 429: throw BalanceProviderError.rateLimited
        default:  throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }
}
```

What to return:

- **One amount** → `.balance(...)`. The user sees a total and a currency.
- **One or more windows** → `.quotaUsage(QuotaUsageSnapshot(windows: [...]))`. A single window is a one-element array, not a separate type.

Each window carries `label`, `kind`, `remainingPercentage` (**remaining**, not used), `resetAt`, `isAvailable`. Use `.fiveHour` / `.week` / `.month` for `kind`; the visible label comes from `LocalizedStrings`, never hard-coded in the provider.

Decode defensively:

- numbers arrive as `"68.65"`, `68.65` or `Decimal` — funnel them through one parser;
- timestamps may or may not carry fractional seconds;
- a missing field should throw, not silently become zero.

If the endpoint rejects generic clients (Cloudflare in front, for example), send a stable User-Agent. **Do not** put the release version in it.

## 3. Credentials

| Mode | When | Consequence |
|---|---|---|
| `.appManagedAPIKey` | The provider only issues a key the user pastes | Console can save/replace/delete; Keychain is the only source |
| `.localExternalConfiguration` | The CLI already stores credentials (`~/.codex/auth.json`, OpenCode's SQLite, …) | Read-only. The Console offers no save/delete |

Local-configuration providers are **decorators** wrapped around `KeychainCredentialStore`:

```swift
let store = OpenCodeCredentialStore(delegate: CodexCredentialStore(delegate: KeychainCredentialStore()))
```

Two hard rules:

1. **Read-only.** Never write back to the CLI's file or database, never copy credentials elsewhere.
2. **Express capabilities with protocols, not `as?`.** Once a decorator wraps the store, `as? CodexCredentialStore` is always `false` and features disappear silently — that is how the 打开配置 button vanished in #13. Add a protocol (like `LocalConfigurationProviding`) and have every decorator forward to its delegate.

A key deleted in the Console while the UI still says "configured" is expected: the real credential lives in the CLI.

## 4. Descriptor and registry

All wiring lives in `BuiltInProviderRegistry.default`. One entry:

```swift
ProviderRegistration(
    descriptor: ProviderDescriptor(
        id: .example,
        displayName: "Example",                 // Console card title
        menuPrefix: "EX",                       // short prefix next to the menu bar icon
        credentialAccount: "example-api-key",   // Keychain account, must be unique
        homepageURL: URL(string: "https://example.com/usage")!,
        detailKind: .quotaUsage,                // .balance or .quotaUsage
        credentialManagement: .appManagedAPIKey,
        accessPurpose: .planQuota,
        menuTitlePrefix: "EX"                   // nil means the title has no prefix (see Codex)
    ),
    makeProvider: { ExampleProvider() }
)
```

`menuPrefix` and `menuTitlePrefix` serve different purposes and may differ: the first is drawn next to the menu bar icon, the second is prepended to the title. Codex uses `"GPT"` + `nil` deliberately.

## 5. UI: usually you do not touch a view

This is what the v0.4.0 refactors bought:

| You fill in | The UI becomes |
|---|---|
| `accessPurpose` | Status wording: `.planQuota` → 计划可用/计划已用尽; `.prepaidBalance` → 可用/余额不足 |
| The snapshot shape | Number format, hero amount, secondary rows (label / value / trailing) |
| `detailKind` | Console metric columns (Total balance vs Detail) |

Only three surfaces need a human look:

1. Menu bar panel — hero area as Primary, three-column rows as a secondary provider;
2. Console Home — the metric box;
3. Console API — credential state, buttons, "open config".

**Never write `if id == .xxx` in a view.** When a provider needs different behaviour, put the answer in `APIProviderSummary` / `ProviderDetailRow` / `ProviderSnapshotPresentation` and let the view read fields.

## 6. Brand assets

1. **Prefer the official SVG** (brand page or the repo's `brand/` directory). Never typeset a wordmark with a system font.
2. Compose a header lockup (mark + wordmark) named `<id>-logo-header.svg`, with an optional `.png` fallback.
3. Add a measurement to `ProviderLogoMetrics.template(for:)`:
   - `canvasWidth/Height`: the asset's own canvas;
   - `wordmarkHeight`: full ink height of the lettering;
   - `xHeight`: the height of the small letters. **Anchor on x-height, not the bounding box** — lowercase, all-caps and pixel typefaces carry very different ascenders and descenders, so bbox-anchoring makes four providers look four sizes;
   - `visualScale`: for typefaces that read larger at the same x-height. Judge with three questions: are the strokes clearly heavier? is it all caps? is it a block or pixel face? The more yeses, the lower the value (below 1).
4. The menu bar icon is separate: `<id>-menu-icon-template.png` (a template image so macOS can tint it).
5. Fallback chain: SVG → PNG → text template. **Never** fall back to `Bundle.module`: SwiftPM's accessor calls `fatalError` when the resource is missing, and the packaged app crashes on launch.

Record the asset's origin and licence (for example: MIT / © 2025 opencode).

## 7. Tests and acceptance

Know who checks what, so you do not spend effort where something already does:

| Checked by | What | If you forget |
|---|---|---|
| The compiler | Exhaustive switches on `ProviderID`: `ProviderLogoMetrics.template(for:)`, three in `ProviderVisualCatalog`, `FixtureMode.sampleSnapshot(for:)` | Build fails |
| Tests | `ProviderOnboardingTests`: descriptor fields, unique credential accounts, logo metrics, fixture sample, window labels | Suite goes red |
| You | The registry field *contents*, capability protocols forwarded by every decorator, localisation wording, README and release notes | Silently does nothing |

Tests you must add:

- decoding: happy path, missing field, number-as-string, fractional seconds;
- error mapping: 401 / 403 / 429 / 5xx;
- credentials: read priority, missing and malformed;
- window labels and reset formatting (one case per language);
- logo metrics: `ProviderLogoMetrics.template(for:)` returns a value.

Then:

```bash
Scripts/verify.sh        # tests and app build — neither is optional
```

Take three screenshots: menu bar panel, Console Home, Console API.

Finally run `ProviderOnboardingTests`. It walks `ProviderID.allCases` and checks descriptor fields, unique credential accounts, logo templates, the fixture sample and window labels. **If you forgot something, it goes red.**

## 8. Known traps

| Symptom | Cause | Fix |
|---|---|---|
| The packaged app crashes on launch | `Bundle.module` used for a missing resource; SwiftPM calls `fatalError` | Ship the resource, and fall back to the text template |
| The 打开配置 button disappears | A decorator does not implement/forward a capability protocol, so `as?` fails | Add a protocol and forward it in every decorator |
| Four providers, four logo sizes | Hand-tuned frames with no shared anchor | Derive sizes from `ProviderLogoMetrics` x-height |
| The DMG has no logo | The packaging script does not copy the new extension | Recursive resource copy; abort when `AppIcon.icns` is missing |
| A Keychain prompt appears while verifying | A rebuild changes the ad-hoc signature | Ask the user to click 始终允许 — it is expected |

## Appendix A: the OpenCode case

Five "wrong → right" pairs, in the order they happened. This is the most valuable part of the document because all of it is real.

1. **Wordmark**: typeset `opencode` in SF Pro → replaced with the official SVG pixel wordmark. A typeset wordmark never matches at any size.
2. **Sizing**: frames tuned by eye, four providers at four sizes → measured x-height anchoring, plus a `visualScale` correction for the block typeface's visual weight.
3. **Credentials**: the Console tested `as? CodexCredentialStore` → wrapping the store in a decorator made that test permanently false, so 打开配置 vanished silently → introduced `LocalConfigurationProviding`, forwarded by every decorator.
4. **Config entry**: the view decided `if id == .codex` before showing the button → the store now answers "where is this provider's local config", and the button is disabled with a hint when there is none (#13).
5. **Snapshot shape**: single windows used `PlanUsageSnapshot`, multi-window used `QuotaUsageSnapshot`; two types meant every switch was written twice and the panel grew two row styles → collapsed into `.quotaUsage`, where a single window is just a one-element array (#64, #65).

The same lesson runs through #9 and #80: the "three-column alignment" work was a downstream consequence of the split shape. Only once the data layer had one shape could the UI have one grid.

## Appendix B: checklist

```
[ ] Three decisions: what it sells / what it returns / where credentials live
[ ] Provider file + error mapping + defensive decoding
[ ] Credentials: app-managed, or decorator + capability protocol
[ ] ProviderID case + registry entry (8 fields)
[ ] Brand assets: official SVG, <id>-logo-header, <id>-menu-icon-template
[ ] ProviderLogoMetrics measurements (canvas / wordmark / x-height / visualScale)
[ ] Fixture sample (the compiler reminds you)
[ ] Tests: decoding / errors / credentials / labels / logo metrics
[ ] Scripts/verify.sh + three screenshots
[ ] README and release notes
```
