# Task 2 Report: Manual Reset Credits Client and Formatter

## Scope

- Implemented `CodexManualResetCreditsProvider`
- Implemented `CodexManualResetCreditsFormatter`
- Added provider tests and formatter tests
- Registered the new test suites in `APIInquiryCoreTestsRunner`

## TDD Evidence

### RED

1. Added failing tests in:
   - `Sources/APIInquiryCoreTestsRunner/CodexManualResetCreditsProviderTests.swift`
   - `Sources/APIInquiryCoreTestsRunner/CodexManualResetCreditsFormatterTests.swift`
   - `Sources/APIInquiryCoreTestsRunner/main.swift`
2. First runner attempt inside the managed sandbox failed before manifest evaluation because SwiftPM hit `sandbox-exec: sandbox_apply: Operation not permitted`.
3. Re-ran the exact required command with approval outside the sandbox:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

4. RED result after the approved run:
   - compile errors for missing `CodexManualResetCreditsProvider`
   - compile errors for missing `CodexManualResetCredit`
   - compile errors for missing `CodexManualResetCreditsSnapshot`
   - compile errors for missing `CodexManualResetCreditsFormatter`
   - compile errors for missing `CodexManualResetCreditsDisplayState`

This confirmed the tests were exercising genuinely missing production code first.

### GREEN

After implementing the provider and formatter, re-ran:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

Result:

- `PASS: 538 expectations`

## Behavior Implemented

### Provider

- Calls `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- Uses `CodexCredentialParser.parse(_:)`
- Sends:
  - `Authorization: Bearer <token>`
  - `Accept: application/json`
  - optional `ChatGPT-Account-Id`
- Maps status codes:
  - `401/403` -> `authenticationFailed`
  - `429` -> `rateLimited`
  - other non-200 -> `serverError`
- Decodes:
  - top-level `{ "credits": [...] }`
  - nested `{ "payload": { "credits": [...] } }`
  - nested `{ "data": { "credits": [...] } }`
- Treats malformed JSON as `decodingFailed`
- Treats missing `credits` as `missingBalanceInfo`
- Uses flexible ISO-8601 decoding for credit dates

### Formatter

- Added `CodexManualResetCreditsDisplayState`
- Counts only credits where:
  - `redeemedAt == nil`
  - `expiresAt > now`
- Chinese loaded summary format:
  - non-zero available credits: `N 张 · M/D 到期`
  - zero available credits: `0 张`
- State text:
  - `idle` -> `--`
  - `loading(previous: nil)` -> `查询中`
  - `failed(previous: nil)` -> `查询失败`
- If `loading` or `failed` has cached data, formatter reuses the previous summary

## Files Changed

- `Sources/APIInquiryCore/Providers/CodexManualResetCreditsProvider.swift`
- `Sources/APIInquiryCore/Formatting/CodexManualResetCreditsFormatter.swift`
- `Sources/APIInquiryCoreTestsRunner/CodexManualResetCreditsProviderTests.swift`
- `Sources/APIInquiryCoreTestsRunner/CodexManualResetCreditsFormatterTests.swift`
- `Sources/APIInquiryCoreTestsRunner/main.swift`

## Self Review

- Stayed within the task-owned file set
- Did not touch `UsageConsoleViewModel`, Menubar, `BalanceRefreshController`, or `ProviderSnapshot`
- No real token handling or persistence was added
- Decoder supports the required top-level `credits` shape and a small nested-envelope compatibility layer
- Implementation follows the existing Codex provider error mapping and request style without broad refactors

## Reviewer Fixes - 2026-07-01

### Summary

- Fixed `CodexCredentialParser.parse(_:)` so access tokens from raw input and auth JSON sources all normalize an optional `Bearer ` prefix.
- Empty tokens after stripping `Bearer` now fail with `BalanceProviderError.authenticationFailed`.
- Added coverage for JSON `tokens.access_token: "Bearer json-token"` returning `json-token`.
- Added coverage for auth JSON `tokens.account_id` forwarding as `ChatGPT-Account-Id` in `CodexManualResetCreditsProvider`.
- Added coverage that `.loading(previous:)` and `.failed(previous:)` reuse the cached manual reset summary.

### Test Output

Initial sandboxed run failed before tests:

```text
sandbox-exec: sandbox_apply: Operation not permitted
```

Approved RED run before the parser fix:

```text
FAIL: 2 failure(s) across 540 expectations
- auth json bearer token normalized: expected json-token, got Bearer json-token
- empty bearer token should fail
```

Final approved run:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

```text
PASS: 543 expectations
```
