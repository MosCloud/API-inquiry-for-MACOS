# Changelog

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.4.3] - 2026-11-02

### Added

- A Refresh control in the Console's Home header: it refreshes every added provider and, when Codex is present, the manual-reset credits too. The credits keep their own subsystem — only the trigger is shared, and failures stay isolated. (#109)
- Provider cards on Home can be reordered from a grip in the bottom-right dead strip. The list reflows live while dragging and auto-scrolls within 40 pt of either edge; order persists, the menu bar primary does not move, and the context menu plus accessibility actions share the same code path. (#110)
- The install window is drawn by `Scripts/generate-dmg-background.swift` instead of a hand-written PNG encoder, and ships in two languages: `package-dmg.sh --all` builds `API-Inquiry-vX.Y.Z.dmg` and `-en.dmg` from one app and asserts both carry the same binary. A static picture cannot follow the user's system language, so the choice is made at download time. (#107)
- `Scripts/dmg-layout.env` is the single owner of the window geometry, read by the background generator and by `package-dmg.sh`. Duplicating it is how the old chevron sat 9.5 pt off the icon midpoint. (#107)

### Changed

- `Scripts/version.env` gained `DMG_BASENAME_EN`, and `ReleaseVersionConsistencyTests` now checks both DMG basenames against the app version. (#107)
- `AGENTS.md` stage 2 now requires a six-line boundary checklist in the issue before implementation, and records why: four rounds of #110 went into cases nobody asked about. (#118)

### Fixed

- The Console's scroller drew over the provider cards. The content now reserves the scroller's width and the scroll view bleeds that much into the window margin, so both margins stay symmetric. (#114)
- A cancelled drag left the reordered card stuck in its lifted state; a mouse-button watcher now ends the gesture wherever it ends. Per-row drop targets also oscillated — up to six hops in 130 ms — and are replaced by one drop target indexed by pointer position. (#110)

## [0.4.2] - 2026-11-02

### Added

- `WorkBuddyBalanceProvider.nextExpiry(in:after:)`, which ranks only packages that can still lose something: remaining credits above zero, and an expiry ahead of this refresh. (#102)
- `docs/provider-onboarding.md` now separates derived fields from the total: a correct sum does not make a date, ratio or label correct, and the vendor's own page is authoritative for semantics but can lag on numbers. (#104)

### Fixed

- WorkBuddy's "next expiry" ranked a lapsed package. A check-in package that expired at 11/02 16:15 still carried a cycle end of 11/05, so it survived the package window holding nothing, and its expiry won the minimum — the Console showed a date in the past while the vendor's screen showed 11/08. Replayed against the live account after the fix: 2026-11-08 15:06:51. (#102)

## [0.4.1] - 2026-11-02

### Added

- WorkBuddy provider (CN region only): reads the desktop app's sign-in, decrypts its at-rest credential, and shows the remaining credits in the menu bar and Console. The Console API page opens WorkBuddy's own config file. (#94)
- `BalanceSnapshot.refreshingAt`, the counterpart to `expiringAt`: a subscription allowance is topped up at its cycle end while a promotional grant is lost at its expiry, so the two dates answer different questions. (#94)
- The `CREDITS` unit in `ProviderValueFormatter`, rendered as a localised unit rather than a currency symbol. (#94)
- Console titles for a credit balance (「总积分」/「赠送积分」), carried on the summary rather than derived in the view. (#94)
- `docs/provider-onboarding.md` gained a section on encrypted credentials, the UI constraints that were only in code, and Appendix D walking the WorkBuddy case. (#95)

### Changed

- The menu bar panel's balance row keeps the unit in its trailing cell; it had carried the expiry date, which read as a fraction beside the amount. (#94)
- The Console shows a prefixed date line under each credit metric (`Refreshes 11/30` / `Expires 11/05`) instead of joining value and date into one string. (#94)
- WorkBuddy's menu bar icon is 16×16, sized by optical weight: a filled badge covers more ink than a bare glyph in the same box. (#94)
- `ProviderLogoMetrics` documents the two-line case: the x-height anchor is one line's cap height, not the total. (#95)

### Fixed

- WorkBuddy's brand assets render as knockout art. The official lockup is a solid colour bitmap (45.4% opaque) while every other provider's asset is a transparent knockout (67–81%), so a template render collapsed it into two blank white slabs. Now 41.8% opaque. (#94)
- The billing request's package window reaches the client's own ~100-year horizon. A 36.9-day window still answered HTTP 200 but silently dropped the monthly package: 36 packages / 2,389 credits instead of 37 / 2,856. (#94)
- A non-zero application-level `code` inside an HTTP 200 body is treated as an error instead of an empty balance. (#94)
- The menu-bar icon loader rejects a solid bitmap's alpha channel before wiring, pinned by the measurement documented in the guide. (#95)

## [0.4.0] - 2026-11-01

### Added

- OpenCode provider: reads the local OpenCode credentials and shows its usage windows in the menu bar and Console; the Console API page can open OpenCode's own config file. (#13)
- The DeepSeek card gained a granted-balance column, and its amount metric was renamed from "Detail" to "Total balance". (#78)
- A failed refresh now marks the menu bar value as stale instead of presenting old data as current. (#39)
- Clicking the development version label in Console copies the commit of the running build. (#52)
- Added a bilingual provider-onboarding guide covering registry fields, logo assets, fixtures and tests. (#17)
- The project is MIT licensed, with a separate record of third-party brand assets and trademarks. (#86)

### Changed

- The menu bar panel is tighter: 442pt down to 364pt, with the hero area keeping only the current window and folding the other windows into one summary line. (#19)
- Secondary providers share one three-column grid (window / remaining / reset), and balance providers align their amount and currency to the same columns. (#9, #80)
- Column widths now fit the values on screen instead of reserving fixed space (typically 39pt / 48pt / 65pt). (#80)
- The secondary rows share one type size; amounts keep one decimal and drop the currency symbol that duplicated the currency column. (#80)
- Status wording follows what a provider sells: subscription plans read "Plan available / Plan exhausted", prepaid balances read "Available / Balance low". (#64)
- Zhipu's menu bar label shows only the percentage and is fully localised; warning colours match the other providers. (#42)
- Provider logos scale from one shared cap-height baseline, so the four wordmarks read the same size.
- Rapid refreshes and key saves are coalesced instead of dropped. (#40)

### Fixed

- Removed the stray "Plan Next Resets" column that only the Zhipu card had in Console Home. (#74)
- Fixed a launch crash when a provider image was missing.
- Fixed the Codex local-configuration hint disappearing once OpenCode joined the credential chain. (#13)
- Fixed credential failures for Codex and OpenCode pointing somewhere other than their own CLI. (#37)
- Plan usage percentages now say "remaining" rather than "used", matching every other provider. (#38)

### Removed

- Removed the duplicate agent-instruction redirect stubs (`AGENT.md` / `AGENT_zh.md`); `AGENTS.md` is the only contract.

## [0.3.16] - 2026-10-30

### Fixed

- The OpenAI/Codex Credits balance now shows at most two decimals, so a value such as `64999.557415` reads `64999.55` instead of looking like a floating-point error.
- The displayed value is truncated rather than rounded, so it never exceeds the credits actually left; whole balances stay whole (`65000`, not `65000.00`).
- Missing, malformed, or negative Credits still show `--`, unlimited credits still read `Unlimited`, and the 5h/1W quota detail and top status badge are unchanged.

## [0.3.15] - 2026-08-26

### Added

- The OpenAI/Codex card on Console Home now shows the raw Credits balance from the usage response, with a `Credits` unit and no currency conversion.
- An explicit zero reads `0 Credits`, and unlimited credits use the localized `Unlimited` label.

### Changed

- Missing, malformed, or invalid Credits show `--` while the valid 5h/1W quota detail, top status badge, and manual-reset information stay available.

## [0.3.14] - 2026-07-31

### Added

- OpenAI/Codex quota in the menu bar now shows only the remaining percentage: the five-hour window when present, or the weekly window when that is the only quota returned.
- Opening the menu bar panel lists the remaining percentage and reset time for every recognized quota window.

### Changed

- The menu bar panel keeps a stable native corner and material appearance on current macOS.

### Fixed

- Weekly-only OpenAI/Codex quota is now recognized and displayed correctly instead of breaking when the response has no five-hour window.

## [0.3.12] - 2026-07-13

### Changed

- Compact menu bar quota labels are now `5H` and `1W`, making the active window quicker to recognize.

### Fixed

- A weekly-only OpenAI/Codex response is now identified as weekly instead of being mislabelled as a five-hour quota.

## [0.3.11] - 2026-07-07

### Changed

- Console appearance is more consistent in light mode.
- Console feedback no longer stacks provider messages.
- Menu refresh and manual-reset refresh share one feedback state.

### Fixed

- A malformed local Codex login file now shows a visible warning instead of failing silently.
- The Console window now matches the size of its content.

## [0.3.10] - 2026-07-03

### Added

- The OpenAI/Codex manual-reset summary in Console Home opens a detail sheet listing every available reset card.
- Reset details show granted and expiration times in the current system time zone.

### Changed

- Time displays consistently follow the system time zone and 12-hour/24-hour preference.

### Fixed

- A refresh still in flight no longer restores removed or changed Codex state.
- Manual-reset results are no longer reused after the Codex credentials change.
- An unconfigured Codex row no longer exposes an empty manual-reset detail action.
- Codex reset timestamps sent as numeric millisecond strings are now parsed.

### Removed

- Console Home no longer has a separate last-updated column, giving quota and manual-reset details more room.

## [0.3.9] - 2026-07-01

### Added

- The OpenAI/Codex card on Console Home shows Codex manual reset credits, including the available reset count and nearest expiration.
- Manual reset credits can be refreshed on their own without joining the menu bar refresh.

### Changed

- Manual-reset checks use a separate low-frequency cache, so they do not block the regular refresh or a manual menu bar refresh.
- Menu refresh and manual-reset refresh share the same in-progress, success, and failure feedback.

### Fixed

- Repeated menu bar refreshes no longer make the refresh icon spin faster over time.

## [0.3.8] - 2026-06-03

### Fixed

- An incomplete OpenAI/Codex quota response no longer briefly shows only the 5-hour window while hiding the 7-day window.
- Incomplete responses are retried once before the refresh is treated as unavailable.
- If the retry is still incomplete, the last complete snapshot stays on screen instead of being replaced with partial data.
- Quota percentages keep the fractional precision returned by the service, matching the official Codex display.

## [0.3.7] - 2026-05-30

### Changed

- The refresh icon turns forward at a calm, steady pace and stops naturally when the refresh finishes.
- Balance, usage, and quota numbers change more smoothly on newer macOS, with macOS 13 still supported.
- Save, delete, warning, and error messages are easier to notice, and warning colours are softer and consistent in light and dark mode.
- Menu bar status, quota windows, provider rows, badges, and icon buttons have clearer accessibility descriptions.

### Fixed

- API access status no longer takes the wrong colour after a language change.
- The refresh animation no longer appears to pause or jump backward near the end of a turn.
- New motion effects are reduced or removed when Reduce Motion is enabled.
- Console Home provider rows keep their internal buttons reachable by assistive technologies.

## [0.3.6-Refactor] - 2026-05-30

### Changed

- Multi-provider refresh runs providers concurrently while each provider keeps its own loading and error state.
- Codex configuration lookup is read-only by default; folders are created only when explicitly requested.
- Settings identifies this validation build as v0.3.6-Refactor.

## [0.3.6] - 2026-05-29

### Added

- The API page offers Open Config for OpenAI/Codex, locating the local auth configuration used for quota checks.

### Changed

- Console API rows are compact standalone cards with provider identity, access status, purpose, and actions on one line.
- Provider chips on the API page now match Home, with balanced logo sizes and a denser macOS Settings-style layout.
- The key action is shortened to "Replace Key", and access-purpose text now distinguishes recharge balance from plan quota.

### Fixed

- OpenAI/Codex plan quota parsing no longer fails when the response returns null reset fields.
- Unavailable providers show neutral grey status badges instead of warning-coloured ones.

## [0.3.5] - 2026-05-26

### Changed

- Console Home provider rows now use the menu panel's translucent visual language, with a soft health-tinted background.
- Home resource badges distinguish balance and quota providers with sufficient, low, and critical states.
- Aggregated quota health follows the most urgent of the 5-hour and weekly windows.
- Spacing, module height, translucency, and section titles are aligned across Home, API, and Settings.

### Fixed

- Home and API content scrolls vertically instead of clipping provider modules at the bottom of the window.
- OpenAI/Codex-style providers without key management no longer show key controls, only removal.
- Settings no longer drifts the navigation and section title, and reports v0.3.5.

## [0.3.4] - 2026-05-22

### Changed

- The primary number in the menu panel now uses health colours, based on remaining balance, used percentage, or each quota window.
- The warning colour is a brighter amber, while success and critical keep their existing tones.
- DeepSeek and Zhipu primary numbers share a stable 42 pt size, with smaller symbols and units.
- The app icon's usage bars echo the same health colours in a softer icon treatment.
- The DMG install window has a larger drag-to-Applications layout, a clearer arrow, and centred targets.

### Fixed

- The primary number no longer changes size between launch and switching the primary provider in Console.

## [0.3.3] - 2026-05-20

### Changed

- Primary provider status now uses the same green as secondary provider status in both languages.
- The Console Home marker for the menu bar provider uses the same blue as AutoStart.
- A new Settings page holds the language setting, version information, and a Project Homepage button.

### Fixed

- The Console window title no longer shows the opposite language after switching between Chinese and English.
- Auto language mode now follows the system language order instead of choosing Chinese whenever Chinese appears anywhere in the preferred-language list.

## [0.3.2] - 2026-05-20

### Added

- Chinese UI: when macOS prefers Chinese, the app shows Chinese by default, and Console Home offers Auto / 中文 / English.
- The language choice is remembered, and Auto follows the system language.
- Menu details and the Console update together when the language changes.

### Changed

- Menu details, Console pages, buttons, statuses, errors, settings feedback, last-updated text, and reset text are localized in both languages.
- Chinese uses `API 密钥` and `密钥串`; Codex quota labels use `5 时` and `1 周`, while the menu bar keeps `5h xx%`.
- The menu bar status text now uses the official macOS menu bar font, size, and weight.

## [0.3.1] - 2026-05-18

### Added

- Added an OpenAI/Codex provider that queries ChatGPT/Codex session quota and reads the local Codex login automatically, so no OpenAI Platform key is needed.
- When it is the Primary Provider, the menu bar shows the OpenAI icon with 5h remaining quota, and the detail panel shows the 5h and 7d windows.
- As a secondary provider, it shows 5h and 7d on separate lines, and Console Home shows the current plan.
- Console Home labels quota semantics explicitly: Zhipu is marked `used`, and OpenAI/Codex is marked remaining.
- Added OpenAI header, logo, and 16×16 menu icon assets.

### Changed

- Zhipu as a secondary provider shows its usage and reset time on one line.

### Removed

- Removed the Last updated row from secondary providers; the timestamp stays on the primary display.

## [0.3.0] - 2026-05-18

### Added

- Built-in multi-provider catalog, starting with DeepSeek and Zhipu GLM Coding Plan.
- Zhipu plan usage, including plan window, usage percentage, and next reset time.
- The menu bar shows only the Primary Provider — DeepSeek balance or Zhipu plan usage such as `5h 17%` — and the menu panel features it while listing other providers as compact rows.
- Console can add providers, save/replace/delete per-provider keys, and choose the Primary Provider.
- Each provider has its own Keychain account and independent refresh, snapshot, and error state.

### Changed

- Home and API layouts align provider cards, metric columns, actions, and logos.
- The menu panel refresh action now refreshes every added provider, not only the Primary Provider.
- Detail formatting is polished: currency and plan-usage typography, plus system 12/24-hour times.

## [0.2.0] - 2026-05-17

### Added

- Added a local Console window with Home and API pages.
- Key setup, replacement, and deletion moved from the menu bar panel into Console.
- Console Home shows provider key status, validation status, and balance state; the API page manages provider keys.
- Provider names in Console are clickable, and DeepSeek opens its usage page.

### Changed

- The menu bar panel stays lightweight, with balance status, Console and refresh actions, AutoStart, and quit.

## [0.1.1] - 2026-05-17

### Added

- Clearer first-run guidance for configuring a DeepSeek API key.
- Refresh failures offer retry, key replacement, and key deletion.
- Structured save feedback and an inline delete confirmation.
- A visible in-progress state for manual refresh.
- Versioned DMG packaging with a matching SHA-256 checksum.

## [0.1.0-alpha.1] - 2026-05-15

### Added

- Initial public alpha: a native macOS menu bar app for checking DeepSeek API balance.
- Balance query through the official DeepSeek balance API, with the key stored in the macOS Keychain.
- Five-minute automatic refresh plus manual refresh from the menu bar.
- Native menu bar UI, an AutoStart launch-at-login toggle, and a custom app icon.
- Last-updated time follows the system 12-hour or 24-hour setting.
