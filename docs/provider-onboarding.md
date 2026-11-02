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

Local-configuration providers are **decorators** wrapped around `KeychainCredentialStore`.

### 3.1 Wire it into the running app (the step everyone forgets)

Writing the decorator only makes it exist; the app never uses it until it is in the chain, which lives in `Sources/APIInquiryApp/App/APIInquiryApp.swift`:

```swift
let store = LocalBoxCredentialStore(
    delegate: OpenCodeCredentialStore(
        delegate: CodexCredentialStore(delegate: KeychainCredentialStore())
    )
)
```

**Order does not matter, forwarding does.** Every decorator must pass providers it does not own straight to its delegate (copy `OpenCodeCredentialStore.configurationURL`). Answering `nil` for the rest swallows the 打开配置 entry of a provider above or below it — it compiles, every test stays green, and the button is simply disabled forever.

(This used to be a trap: Codex answered `nil` for non-Codex providers, which turned the order into an undocumented rule. Fixed in #83.)

### 3.2 Capabilities are protocols, not `as?`

Once a decorator wraps the store, `as? CodexCredentialStore` is always `false` and features disappear silently — that is how the 打开配置 button vanished in #13. There are two capability protocols today; implement the ones you need and forward them through every layer:

- `LocalConfigurationProviding` — which file the 打开配置 button opens;
- `CodexCredentialProviding` — the warning shown when Codex's session file is malformed. **A new decorator that does not forward it silently removes that warning.**

### 3.3 Two behaviour rules

1. **Read-only.** Never write back to the CLI's file or database, never copy credentials elsewhere. A key deleted in the Console while the UI still says "configured" is expected: the real credential lives in the CLI.
2. **What 打开配置 points at**: return the file when it exists, `nil` when it does not (button disabled, hint shown). Codex and OpenCode also fall back to the containing directory; if you copy that behaviour, put it in a test rather than leaving it to guesswork.

### 3.4 Test the forwarding

Forwarding is behaviour, not configuration, so give it a test: wrap your decorator over `InMemoryCredentialStore` and assert that **a provider it does not own** still returns the delegate's answer, while its own provider returns its own.

The chain itself has no automated test (the runner does not compile the App), so after changing it, click 打开配置 once in Console → API by hand.

### 3.5 When the stored credential is encrypted

Some desktop apps no longer keep the token in plain text. WorkBuddy 5.6.0+ writes:

```json
"accessToken": { "$wbEncrypted": 1, "envelope": "<base64 of {suite,keyId,nonce,authTag,ciphertext}>" }
```

A reader that only accepts strings sees **no credential at all** and reports the account
as signed out — the user is told to sign in again, which cannot help. This is a different
class of problem from "the CLI stores its token in a file", and it needs three things the
plain decorator does not.

**The key is not a user secret.** It is a build-time constant compiled into the app, which
means two consequences:

- Do **not** freeze a copy of it in this repo; it changes whenever the vendor ships a new
  build.
- Do **not** ask the user to enter anything. There is nothing for them to enter.

Ask the app that wrote the file. For an Electron app the value usually lives behind one of
its own native bindings, reachable by running the app's binary as plain Node:

```bash
ELECTRON_RUN_AS_NODE=1 "/Applications/<App>.app/Contents/MacOS/<binary>" \
  -e "process.stdout.write(process._linkedBinding('<binding>').loggerGet())"
```

`WorkBuddyCredentialStore` does this; the three rules it learned:

1. **Derive the key exactly as the vendor does.** WorkBuddy hashes the payload's base64
   **string**, not its decoded bytes. Hashing the decoded bytes yields a different key and
   every field then fails the AES-GCM tag with no hint about why.
2. **Verify before decrypting.** The envelope names the key it was sealed with (`keyId`);
   compare it and fail loudly on a mismatch instead of returning garbage.
3. **Get the AAD byte-exact.** WorkBuddy's additional-authenticated-data is a
   length-prefixed transcript (`WB-AAD\0`, scheme, format id, suite, keyId, framing code,
   two zero bytes). Wrong byte order is indistinguishable from a wrong key: GCM fails the
   tag either way.

**Cache the key in memory, never on disk**, and key the cache on the envelope's `keyId` so
a vendor upgrade that rotates the key re-derives on the next read instead of failing until
restart. Asking the app costs 60–90 ms on WorkBuddy (a cold Electron start, measured), so
re-running it on every refresh is affordable but wasteful.

**Separate "signed out" from "signed in but unreadable".** These look identical from the
outside — zero usable credentials — but the advice for each is opposite, and the generic
one ("sign in again") is the one action that cannot help the second case. Give the
unreadable case its own error carrying the fix ("the desktop app must be installed"), and
expose whether re-signing-in can help:

```swift
public var isSignInProblem: Bool   // false for every encrypted-credential case
```

**Guard the subprocess.** No stdin, a hard timeout, and read stdout only; a stalled child
must not block a refresh. On macOS, find the binary by reading the bundle's own
`CFBundleExecutable` (Electron apps ship a binary literally named `Electron`) and check
`CFBundleIdentifier` before executing, or you will launch an unrelated Electron app:
`<bundle>/Contents/MacOS/WorkBuddy` does not exist on a WorkBuddy install.

Finally, **normalise timestamp units by magnitude, not by assumption.** The desktop
document writes `expiresAt` in **milliseconds**; plugin-side copies of the same field use
**seconds**:

```swift
return raw > 1_000_000_000_000 ? raw : raw * 1000
```

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

Two details that are easy to miss:

- Providers write **short English labels** (`"5h"`, `"Week"`); the visible Chinese/English label is derived from `kind` by `LocalizedStrings`. Never write Chinese in the provider.
- Brand assets do not wire themselves: the loader and switches in `ProviderVisualCatalog` are yours to add, or the app silently keeps drawing the text fallback even when the files are correct.

### 5.1 Fit the shape that already exists before inventing one

A new provider's data rarely matches a snapshot field name exactly, and the reflex is to
add a new `ProviderDetailKind` and a matching render path. **Resist it.** Map the data onto
an existing payload first and see whether the UI already reads correctly.

WorkBuddy sells *credits*, which are neither money nor a percentage. The mapping that
worked, with **no view change at all**:

| `BalanceSnapshot` | WorkBuddy |
|---|---|
| `totalBalance` | sum of every package |
| `grantedBalance` | the promotional grants → Console draws 「赠送余额」 by itself |
| `toppedUpBalance` | the monthly allowance |
| `currency` | `"CREDITS"` |

A new `detailKind` costs a render branch, a formatter, status copy, and a test suite for
each. Reusing `.balance` cost one formatter branch. Reach for a new shape only when the
existing ones genuinely cannot carry the meaning — Codex's manual-reset credits are the
real example of that (they are a parallel subsystem, not a `BalanceProvider`).

**When the unit is not currency, say so in `currency` and handle it in the formatter**, not
by writing the unit into the value string. `"CREDITS"` lets `ProviderValueFormatter` swap
the symbol for a localised unit (`¥68.65 CNY` vs `2899.64 积分`) while every layout rule
that already exists keeps working.

### 5.2 What the panel will and will not do for you

These are hard constraints in the current code, not style preferences:

- **The hero area is for quota windows only.** `MenuBarBalanceViewModel.primaryQuotaWindowRow`
  picks the 5-hour window (else the first). A balance provider never reaches the hero — it
  is always a secondary row.
- **A balance row is three fixed columns**, fitted per render to the content on screen.
  Widths are clamped: label `24…46`, value `26…72`, trailing `24…44` (`SecondaryRowColumns`).
  A long value ellipsizes rather than shrinking the font.
- **The trailing cell carries a short qualifier**, whatever shape it takes: a currency code
  (`CNY`), a unit (`积分`), or a date (`11/05`). Keep it under ~5 characters.
- **A date in the trailing cell needs a spelled-out neighbour.** A bare `11/05` beside a
  number reads as a fraction. Either the row's label says what the date means, or the date
  belongs in the Console with a prefix.

### 5.3 Two dates with two meanings must stay two fields

If the provider reports both a refresh and an expiry, keep them apart end to end:

```swift
public let expiringAt: Date?     // this much can be LOST here
public let refreshingAt: Date?   // this much is TOPPED UP here
```

Collapsing them into one "date" makes the panel say the wrong thing about half the balance.
Put each under the figure it actually describes — WorkBuddy's Console shows「下次刷新」
under the total and「最近到期」under the granted figure — and prefix them rather than
joining with `/`, for the same fraction reason.

### 5.4 Never use `minimumScaleFactor` as a truncation guard

It silently renders text smaller instead of exposing the squeeze. It made the balance row's
amounts 90% of everything else in v0.4.0 while every test stayed green. Let the long label
give way (or ellipsize) and keep the numbers at full size.

## 6. Brand assets

A provider lockup is drawn as a **template image**, so the only thing that reaches the
screen is its alpha channel. Everything below follows from that one fact.

### 6.1 Formats: what the four existing providers actually use

| Provider | Header lockup | Menu icon |
|---|---|---|
| DeepSeek | PNG | PNG |
| Zhipu | PNG | PNG |
| Codex (ChatGPT) | PNG | PNG |
| OpenCode | SVG | PNG |
| WorkBuddy | PNG | PNG |

**PNG is the normal case; SVG is the exception.** Prefer a vector when the source is
vector (it rasterises at the exact frame size instead of being resampled), but a PNG is
perfectly acceptable and is what four of the five use. What matters is what is *in* the
alpha channel, not the file extension.

### 6.2 The one rule that matters: ink must be opaque, background transparent

Every lockup is rendered with `.renderingMode(.template)`. A template image carries
**alpha only**: colour is thrown away and macOS re-tints whatever is opaque.

So the asset must be built as a **knockout**: the glyph or mark is opaque, everything
that should read as background is transparent. Measure it before wiring it up:

```bash
# how much of the canvas is opaque?
python3 - <<'PY'
from PIL import Image
im = Image.open("<asset>.png").convert("RGBA")
a = im.split()[-1]
px = a.load()
full = sum(1 for y in range(im.height) for x in range(im.width) if px[x, y] == 255)
print(f"opaque: {full / (im.width * im.height):.1%}")
PY
```

Healthy assets land at roughly **20–45% opaque**:

| Provider | opaque | transparent |
|---|---|---|
| Zhipu | 12.2% | 81.1% |
| OpenAI | 18.9% | 78.9% |
| DeepSeek | 24.6% | 69.0% |
| OpenCode | 25.4% | 67.5% |
| WorkBuddy (rebuilt) | 41.8% | 57.4% |

A **solid colour bitmap** — the usual shape of an app's marketing lockup — is 45%+
opaque with the artwork painted *inside* it in colour. Rendering that as a template
produces one white slab: the mark becomes a featureless block and the lettering fills in.
This is exactly what happened with WorkBuddy; see Appendix D.

**When the official asset is a solid bitmap**, rebuild it as a knockout before wiring it
up: keep the brand-coloured block as ink and turn the light cut-outs (the mark's interior,
the counter-spaces) transparent. Do not hand-invert it to a black-on-white silhouette —
that reverses the figure/ground and the mark stops reading as the same mark.

### 6.3 Where to find the asset

In order of preference:

1. The company's brand or press page.
2. The repo's own `brand/` directory.
3. **Inside the installed desktop app** — see 6.4.
4. Nothing official: draw an SVG that does not depend on a font and say so in a comment
   (`"synthetic asset, no third-party rights"`). Never pass a system-font wordmark off as
   a company logo.

Record the origin and licence next to the loader (for example
`MIT / © 2025 opencode` or `Extracted from WorkBuddy.app 5.9.3, © workbuddy.cn`).

### 6.4 Extracting from an installed Electron app

An Electron app bundles its renderer assets in `Contents/Resources/app.asar`, which is an
archive, not a directory — `ls` cannot see inside it:

```bash
npx --yes @electron/asar extract "/Applications/<App>.app/Contents/Resources/app.asar" /tmp/<app>-asar
find /tmp/<app>-asar -iname "*.svg" -o -iname "*.png" | grep -iE "logo|brand|wordmark"
```

Two traps, both of which cost time on WorkBuddy:

- **A similar product's assets live in the same folder.** WorkBuddy's bundle also ships
  `header-icon-*.svg` — a **CodeBuddy** lockup, a sibling brand with a nearly identical
  filename pattern. Render every candidate and look at it before choosing:
  `qlmanage -t -s 800 -o /tmp/preview <file>.svg`.
- **Do not assume the file named after the brand is the lockup.** `logo-<brand>.svg` in a
  renderer bundle is often the square app icon; the horizontal lockup usually sits in a
  PNG named `*-logo-*.png` at 2–3× the display size.

Anything extracted this way is the vendor's trademark, used to identify the service the
app reads. Say so where the loader is declared, and add the attribution to
`THIRD-PARTY.md`.

### 6.5 Measuring it

Add a measurement to `ProviderLogoMetrics.template(for:)`:

- `canvasWidth/Height`: the asset's own canvas;
- `wordmarkHeight`: full ink height of the lettering;
- `xHeight`: the height of the small letters. **Anchor on x-height, not the bounding
  box** — lowercase, all-caps and pixel typefaces carry very different ascenders and
  descenders, so bbox-anchoring makes providers look different sizes. For a **two-line**
  wordmark this is one line's cap height, not the two-line total;
- `visualScale`: compensation for the wordmark's visual weight. The code computes
  `size = target * visualScale / xHeight`, so **a larger value renders larger**. If the
  face looks small or light at the same x-height, raise it (Codex uses 1.08); if it looks
  heavy or large, lower it.

To measure, find the ink bounding box and the per-line row gaps. **Exclude the mark** —
it spans the full height and would hide the line structure:

```bash
python3 - <<'PY'
from PIL import Image
im = Image.open("<asset>.png").convert("RGBA")
px = im.load(); W, H = im.size
# 1) the mark sits left of a clear vertical gap; the lettering is to its right
cols = [x for x in range(W) if any(px[x, y][3] > 20 for y in range(0, H, 2))]
gx = [(cols[i-1], cols[i]) for i in range(1, len(cols)) if cols[i] - cols[i-1] > 20]
text_x0 = gx[0][1] if gx else 0
# 2) ink rows inside the lettering only
rows = [y for y in range(H)
        if any(min(px[x, y][:3]) < 200 and px[x, y][3] > 20 for x in range(text_x0, W, 2))]
gaps = [(rows[i-1], rows[i]) for i in range(1, len(rows)) if rows[i] - rows[i-1] > 1]
print("ink rows:", rows[0], "..", rows[-1], "| line gaps:", gaps)
PY
```

For WorkBuddy that prints `ink rows: 76 .. 482 | line gaps: [(264, 293)]` — a **two-line**
lockup. One line's cap height is therefore the x-height anchor (189 px), not the 407 px
total.

### 6.6 The menu bar icon

`<id>-menu-icon-template.png`, a template image so macOS can tint it.

**Size it by optical weight, not by matching a number.** A filled rounded badge covers far
more ink than a bare glyph at the same box, so copying another provider's size makes it
read a size larger. The current sizes:

| Provider | Size | Why |
|---|---|---|
| DeepSeek | 20×20 | bare glyph |
| Zhipu | 20×18 | badge, but a thin one |
| Codex | 16×16 | bare glyph |
| OpenCode | 16×16 | bare glyph |
| WorkBuddy | 16×16 | filled badge — 20×20 looked oversized |

### 6.7 Wiring

Add three switch cases and a loader in `ProviderVisualCatalog` for the new id: header
lockup, menu icon size, menu icon. Copy OpenCode's order:
`loadVector` → `loadPNG` → `textTemplateImage`. **Never** fall back to `Bundle.module`:
SwiftPM's accessor calls `fatalError` when the resource is missing, and the packaged app
crashes on launch.

The packaging script already copies `*.png` / `*.icns` / `*.svg` recursively; you only
touch it for a **different** extension.

## 7. Tests and acceptance

Know who checks what, so you do not spend effort where something already does:

| Checked by | What | If you forget |
|---|---|---|
| The compiler | Exhaustive switches on `ProviderID`: `ProviderLogoMetrics.template(for:)`, three in `ProviderVisualCatalog`, `FixtureMode.sampleSnapshot(for:)` | Build fails |
| Tests | `ProviderOnboardingTests`: descriptor fields, unique credential accounts, logo metric values, fixture sample, window labels | Suite goes red |
| You | The registry field *contents*, whether the asset files exist, the `ProviderVisualCatalog` loader, capability protocols forwarded through decorators, the app's decorator chain, README and release notes | Silently does nothing (text fallback, missing button) |

`ProviderOnboardingTests` is **not** full coverage: it checks that the configuration data is complete, not that an asset exists or a view is wired. Green means half the job.

Tests you must add:

- decoding: happy path, missing field, number-as-string, fractional seconds;
- error mapping: 401 / 403 / 429 / 5xx;
- credentials: read priority, missing and malformed;
- window labels and reset formatting (one case per language);
- logo metrics: `ProviderLogoMetrics.template(for:)` returns a value.

Three steps that are easy to miss:

1. **Register the new suite in** `Sources/APIInquiryCoreTestsRunner/main.swift` — an unregistered suite never runs, and nothing tells you.
2. **Two existing tests will go red, and not because of your code**: `ProviderCatalogTests` pins the provider order *and* the credential-account dictionary, `FixtureModeTests` pins the count. Prefer `ProviderID.allCases` / `allCases.count` where you can, so the next provider does not have to touch them again.
3. **For a local-configuration provider, add the chain-forwarding test** (§3.4) — it is the only thing that catches a decorator in the wrong position.

### Reconciling against the vendor's own screen

Green tests do not mean the numbers are right. They mean the numbers match **what you
asserted**, and if your reading of the API is wrong, the tests are wrong in the same
direction.

The real lesson: WorkBuddy's endpoint answered **HTTP 200**, `code: 0`, and produced a
perfectly plausible **2,389 credits** instead of **2,856**. The package window was
mis-specified, so the monthly allowance was silently filtered out. Every test passed,
`verify.sh` passed, and the Console showed a believable number. It was only caught by
opening WorkBuddy's own 套餐与积分 page and comparing.

So after the wiring is green:

1. **Find the vendor's own screen** that shows the same number (their console, dashboard,
   or the CLI's own status command).
2. **Compare values field by field**, not just the total — the total can be right while
   one component is missing and another is double-counted.
3. **If they disagree, trust the vendor's screen.** Your decoding is the suspect until
   proven otherwise.
4. **Pin the disagreement as a regression test.** A fixed total alone would not have caught
   this; the test has to assert the *request* or the *component*, not only the sum.

One more warning, and it has nothing to do with the total: **a correct total does not make
the other fields correct.** In #102 the Console's "next expiry" showed a date that had
**already passed** (11/02) while WorkBuddy's own page said 11/08 — the balance was right to
the cent. The endpoint kept returning a lapsed package whose `ExpiredTime` was gone but
whose `CycleEndTime` was still ahead. It held nothing, so it added nothing to the sum, and
it still dragged `min()` into the past.

So check the **derived fields** (dates, ratios, status labels) on their own — that **a date
shown to the user is never in the past** is the cheapest self-check there is. And when
aggregating, ask whether an input is still meaningful before asking how much it contributes.

"If they disagree, trust the vendor's screen" has a precondition too: **the vendor's page
lags.** At the same moment its balance read 12.38 higher than live data — exactly the
remainder that package held before it lapsed, not yet written off. Split the two: trust the
vendor on **semantics** (what a field means, how a date is computed), but reload its page
before trusting a **number**, and never pin a cached value as your own assertion.

A provider whose data you cannot independently verify has not been accepted yet — you have
only proved that it returns parseable JSON.

### Fixtures lie about local credentials

A `--fixtures` scenario swaps the credential store for `InMemoryCredentialStore` and seeds `"fixture-key"` for every registered account. A local-configuration provider therefore always shows as configured under fixtures, so fixtures cannot verify "no file = not configured". Use a real copy of the app, or inject a temporary file in a unit test.

Then:

```bash
Scripts/verify.sh        # tests and app build — neither is optional
```

Take three screenshots: menu bar panel, Console Home, Console API.

Two provider lists also live in prose: `README.md` / `README_en.md`, and the sentence near the top of `AGENTS.md` that names the providers.

Finally run `ProviderOnboardingTests`. It walks `ProviderID.allCases` and checks descriptor fields, unique credential accounts, logo templates, the fixture sample and window labels. **If you forgot something, it goes red.**

## 8. Known traps

| Symptom | Cause | Fix |
|---|---|---|
| The packaged app crashes on launch | `Bundle.module` used for a missing resource; SwiftPM calls `fatalError` | Ship the resource, and fall back to the text template |
| The 打开配置 button disappears | A decorator does not implement/forward a capability protocol, so `as?` fails | Add a protocol and forward it in every decorator |
| Four providers, four logo sizes | Hand-tuned frames with no shared anchor | Derive sizes from `ProviderLogoMetrics` x-height |
| The DMG has no logo | The packaging script does not copy the new extension | It already copies `png/icns/svg` recursively; only a new extension needs a script change, and a missing `AppIcon.icns` aborts |
| A new provider's 打开配置 is always disabled | A decorator answers `nil` for providers it does not own instead of forwarding | Forward in every layer (§3.1) and lock it with a test |
| A Keychain prompt appears while verifying | A rebuild changes the ad-hoc signature | Ask the user to click 始终允许 — it is expected |
| A provider shows "not configured" although the user is signed in | The stored token is an encrypted wrapper and a strings-only reader finds nothing (§3.5) | Open the field, and give the unreadable case its own error |
| Every decryption fails the AES-GCM tag | The key is derived from the wrong spelling (decoded bytes vs the base64 string) or the AAD is one byte off (§3.5) | Copy the vendor's derivation exactly; a tag failure cannot tell you which |
| The Console shows 0 while the vendor's own panel shows a balance | A non-zero application-level `code` inside an HTTP 200 body, or a query window that silently excludes packages | Treat a non-zero envelope code as an error, and pin the window with a regression test |
| The brand lockup renders as a blank white slab | The official asset is a solid colour bitmap; a template render keeps only alpha, so the whole tile is ink | Rebuild it as a knockout (§6.2) |
| The menu bar icon looks bigger than its neighbours | It is a filled badge, so the same box covers far more ink | Size by optical weight, not by copying a number (§6.6) |
| The "next expiry" shows a date that has already passed | The endpoint returns lapsed packages too: `ExpiredTime` is gone while `CycleEndTime` is still ahead, so the window keeps them with nothing left in them | Ask whether a package can still lose credits before ranking it: remainder above zero, expiry after this refresh (#102) |

## Appendix A: the OpenCode case

Five "wrong → right" pairs, in the order they happened. This is the most valuable part of the document because all of it is real.

1. **Wordmark**: typeset `opencode` in SF Pro → replaced with the official SVG pixel wordmark. A typeset wordmark never matches at any size.
2. **Sizing**: frames tuned by eye, four providers at four sizes → measured x-height anchoring, plus a `visualScale` correction for the block typeface's visual weight.
3. **Credentials**: the Console tested `as? CodexCredentialStore` → wrapping the store in a decorator made that test permanently false, so 打开配置 vanished silently → introduced `LocalConfigurationProviding`, forwarded by every decorator.
4. **Config entry**: the view decided `if id == .codex` before showing the button → the store now answers "where is this provider's local config", and the button is disabled with a hint when there is none (#13).
5. **Snapshot shape**: single windows used `PlanUsageSnapshot`, multi-window used `QuotaUsageSnapshot`; two types meant every switch was written twice and the panel grew two row styles → collapsed into `.quotaUsage`, where a single window is just a one-element array (#64, #65).

The same lesson runs through #9 and #80: the "three-column alignment" work was a downstream consequence of the split shape. Only once the data layer had one shape could the UI have one grid.

## Appendix B: how this guide was tested

It was blind-tested twice: a fresh agent with no context was told to add a fictional provider
using only this document, once with an app-managed key and once with credentials read from a
CLI file. Both produced implementations that passed `Scripts/verify.sh`, and both exposed gaps
that had been invisible to the author — the test-suite registration step, the two existing
tests that pin the provider list, the decorator wiring order, and the fixture illusion around
local credentials. All of them are now written down above.

If you change this guide substantially, run the same experiment: point an agent at it with a
made-up provider and see where it stumbles. Reading it yourself is not a substitute.

## Appendix C: checklist

```
[ ] Three decisions: what it sells / what it returns / where credentials live
[ ] Provider file + error mapping + defensive decoding
[ ] Credentials: app-managed, or decorator + both capability protocols + wired into the APIInquiryApp chain (forward what you do not own)
[ ] Encrypted credential?  open the field, verify keyId, cache the key in memory, and split "signed out" from "unreadable" (§3.5)
[ ] ProviderID case + registry entry (descriptor: 9 required fields + 1 optional)
[ ] Tried an existing snapshot shape before adding a detailKind (§5.1)
[ ] Brand assets: knockout alpha (20-45% opaque, NOT a solid bitmap), <id>-logo-header, <id>-menu-icon-template
[ ] ProviderLogoMetrics measurements (canvas / wordmark / x-height / visualScale)
[ ] Menu bar icon sized by optical weight, not a copied number (§6.6)
[ ] Fixture sample (the compiler reminds you)
[ ] Tests: decoding / errors / credentials / labels / logo metrics
[ ] Two dates that mean different things kept as two fields (§5.3)
[ ] Scripts/verify.sh + three screenshots
[ ] README and release notes
```

## Appendix D: the WorkBuddy case

The second real provider added against this guide (v0.4.1, #94), and the first one whose
credential is encrypted. What it cost, in order.

**1. The credential is not readable as a string.** `auth.accessToken` is
`{$wbEncrypted: 1, envelope: …}`. A strings-only reader reports the signed-in user as
signed out. → §3.5.

**2. The key is a build constant, not a secret.** Asking the installed app for it via
`ELECTRON_RUN_AS_NODE` costs 60–90 ms and needs no user interaction. Freezing the constant
in this repo would have rotted at the next WorkBuddy release. → §3.5.

**3. The AAD transcript took three attempts.** `WB-AAD\0` + a format id + scheme + suite +
keyId + framing byte + two zeros, all length-prefixed except the single bytes. A wrong
order and a wrong key produce the same failure, so there is nothing to bisect on: copy the
vendor's construction verbatim. → §3.5.

**4. A plausible query window silently drops data.** `PackageEndTimeRangeEnd` needed to be
the client's own ~100-year horizon (`3185136e6` ms). A 36.9-day window still answered
**200**, but omitted the monthly package: 36 packages / 2,389 credits instead of 37 /
2,856. No error anywhere. Pin the window with a regression test that parses the request
body. → §7.

**5. The official lockup is a solid bitmap.** 45.4% opaque, artwork painted inside in
colour — every other provider's asset is a 67–81% transparent knockout. Rendered as a
template it became one white slab, which is what the Console chip showed. Rebuilt the
knockout from it (57.4% transparent); a hand-inverted black-on-white silhouette was tried
first and read as a different mark. → §6.2.

**6. The badge looked a size too large at 20×20.** Filled badges carry more ink than bare
glyphs in the same box; 16×16 matched the others optically. → §6.6.

**7. Credits are not money, and "balance" is the wrong word for them.** `currency:
"CREDITS"` plus a formatter branch got the unit right; the Console titles needed their own
strings (「总积分」/「赠送积分」vs 「总余额」/「赠送余额」), carried on the summary rather than
derived in the view. → §5.1.

**8. Two dates, two meanings.** The monthly allowance refreshes at its cycle end; the
promotional grants expire. Collapsing them into one field made the panel state the wrong
thing. Split into `refreshingAt` and `expiringAt`, each rendered under the figure it
describes. → §5.3.

**What did not need touching**, because the shape was reused rather than invented:
`ProviderDescriptor`, `ProviderSnapshot`, the Console card layout, the menu bar hero area,
`BalanceRefreshController`. The whole UI came from filling in one `BalanceSnapshot`.
