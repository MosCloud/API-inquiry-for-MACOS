# v0.3.6-Refactor Runtime Hardening Findings

## Repository State

- Working directory: `/Users/zbw/Desktop/API-inquiry/.worktrees/v0.3.6-Refactor`.
- Current branch: `v0.3.6-Refactor`.
- Current branch head before this hardening work: `9947bde docs: refresh v0.3.6 refactor release notes`.
- `v0.3.6-Refactor` is an existing worktree branch, so the main worktree cannot switch to it directly.

## Project Shape

- Swift Package Manager project targeting macOS 13+.
- Main products:
  - `APIInquiryCore`
  - `APIInquiryCoreTestsRunner`
  - `APIInquiryApp`
- Existing verification commands:
  - `swift run APIInquiryCoreTestsRunner`
  - `swift build`
  - `git diff --check`

## Review Feedback Being Addressed

- `MultiProviderBalanceCoordinator` still had a built-in default provider as a default argument, which is unintuitive for callers that pass a narrower custom registration set.
- `UsageConsoleViewModel.supportsConsoleCredentialManagement(for:)` defaulted to `true` when descriptor metadata was missing; defensive UI behavior should fail closed.
- `ProviderRegistration.makeProvider()` is a factory and may be called by tests; current providers are lightweight, but the expected contract should be explicit.
- `MenuBarBalanceViewModel` still has a default convenience initializer. It is not currently in production app wiring, so this round will not remove it unless review finds a concrete risk.

## Code Hotspots For This Round

- `Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift`
- `Sources/APIInquiryCore/ViewModels/UsageConsoleViewModel.swift`
- `Sources/APIInquiryCore/Providers/ProviderRegistration.swift`
- `Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift`

## Current Architecture Constraints

- Keep `BalanceProvider` metadata-free.
- Keep production coordinator initialization through `BuiltInProviderRegistry.default.registrations`.
- Do not move UI logic or change visual presentation in this round.
