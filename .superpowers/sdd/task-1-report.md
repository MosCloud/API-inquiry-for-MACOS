# Task 1 Report: Shared Codex Credential Parser

## Scope

- Implemented shared `CodexCredential` and `CodexCredentialParser`.
- Switched `CodexQuotaProvider` to use the shared parser.
- Added parser tests and registered them in the custom test runner.
- Did not add any reset credits logic to Menubar, `BalanceRefreshController`, or provider refresh flow.

## TDD Evidence

### RED

1. Added `CodexCredentialParserTests` and registered them in `Sources/APIInquiryCoreTestsRunner/main.swift`.
2. Ran:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

3. Sandboxed run could not compile the SwiftPM manifest because of:

```text
sandbox-exec: sandbox_apply: Operation not permitted
```

4. Re-ran the same command with escalation to obtain real RED evidence.
5. Observed compile failure caused by the missing parser type:

```text
error: cannot find 'CodexCredentialParser' in scope
```

### GREEN

1. Implemented `Sources/APIInquiryCore/Providers/CodexCredentialParser.swift`.
2. Removed duplicated credential parsing from `Sources/APIInquiryCore/Providers/CodexQuotaProvider.swift` and routed `fetchSnapshot(apiKey:)` through `CodexCredentialParser.parse(_:)`.
3. Re-ran:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

4. Result:

```text
Build of product 'APIInquiryCoreTestsRunner' complete! (1.09s)
PASS: 513 expectations
```

## Changed Files

- `Sources/APIInquiryCore/Providers/CodexCredentialParser.swift`
- `Sources/APIInquiryCore/Providers/CodexQuotaProvider.swift`
- `Sources/APIInquiryCoreTestsRunner/CodexCredentialParserTests.swift`
- `Sources/APIInquiryCoreTestsRunner/main.swift`

## Behavioral Notes

- Empty input still maps to `BalanceProviderError.authenticationFailed`.
- Raw token and `Bearer ...` input still normalize to the same authorization token behavior.
- Auth JSON parsing still supports:
  - `tokens.access_token`
  - top-level `accessToken`
  - top-level `access_token`
- Account ID parsing still supports:
  - `tokens.account_id`
  - top-level `account_id`
  - top-level `accountID`

## Self Review

- Kept the parser extraction behaviorally aligned with the previous private implementation.
- Limited edits to the parser/provider/test-runner surface required by Task 1.
- Used only fake tokens in tests and report content.
- No UI, refresh-controller, or manual reset credits changes were introduced.
- `CodexQuotaProviderTests.swift` did not need edits because existing coverage still validates provider request behavior after the parser extraction.

## Follow-up Review Fix

- Added parser-level tests for the alias contract called out in review:
  - `tokens.access_token`
  - top-level `accessToken`
  - top-level `access_token`
  - `tokens.account_id`
  - top-level `account_id`
  - top-level `accountID`
- Re-ran the required verification command and it passed with the existing parser implementation, so no production code change was needed for this review item.
- Verification:

```bash
CLANG_MODULE_CACHE_PATH=/Users/zbw/Desktop/API-inquiry/.build/module-cache swift run APIInquiryCoreTestsRunner
```

```text
PASS: 519 expectations
```
