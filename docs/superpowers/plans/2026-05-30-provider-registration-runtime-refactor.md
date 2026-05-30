# Provider Registration Runtime Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the provider metadata ownership cleanup after `v0.3.6-Refactor` by making `ProviderRegistration` the runtime source of descriptor metadata.

**Architecture:** Provider metadata should flow from `BuiltInProviderRegistry` through `ProviderRegistration` into `ProviderRuntime`. `BalanceProvider` should remain a fetch client with only `id` and `fetchSnapshot(apiKey:)`; credential account and presentation metadata should come from `ProviderDescriptor`.

**Tech Stack:** Swift 5.9, SwiftUI, Combine, custom `APIInquiryCoreTestsRunner`.

**Implementation Status:** Executed as one integrated follow-up refactor on `v0.3.6-Refactor`. Final verification passed with `swift run APIInquiryCoreTestsRunner` (`PASS: 478 expectations`), `swift build`, `git diff --check`, production dependency scans for provider metadata fallback, and one read-only subagent quality review with no blocking findings.

---

## Target Dependency Direction

```text
BuiltInProviderRegistry
  -> ProviderRegistration
      -> ProviderDescriptor
      -> BalanceProvider factory

MultiProviderBalanceCoordinator
  -> ProviderRuntime(descriptor, provider, controller)

BalanceRefreshController
  -> provider.fetchSnapshot(apiKey:)
  -> credentialAccount supplied from descriptor

ViewModel / UI
  -> coordinator descriptor/state
```

## Files

- Modify: `Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift`
- Modify: `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`
- Modify: `Sources/APIInquiryCore/Providers/BalanceProvider.swift`
- Modify: `Sources/APIInquiryCore/Formatting/ProviderValueFormatter.swift`
- Modify: `Sources/APIInquiryCore/Formatting/ProviderDisplayFormatter.swift`
- Modify: `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
- Modify: `Sources/APIInquiryCore/ViewModels/UsageConsoleViewModel.swift`
- Modify: `Sources/APIInquiryApp/APIInquiryApp.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/UsageConsoleViewModelTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/ProviderCatalogTests.swift`

## Task 1: Registration-First Coordinator

- [ ] **Step 1: Write failing coordinator tests**

Add tests in `Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift`:

```swift
@MainActor
private static func testCoordinatorUsesRegistrationDescriptorInsteadOfGlobalCatalog(using harness: TestHarness) {
    let descriptor = ProviderDescriptor(
        id: .deepseek,
        displayName: "Registration DeepSeek",
        menuPrefix: "REG",
        credentialAccount: "registration-deepseek-key",
        homepageURL: URL(string: "https://example.com/registration")!,
        detailKind: .balance,
        credentialManagement: .appManagedAPIKey,
        accessPurpose: .prepaidBalance,
        menuTitlePrefix: "REG"
    )
    let coordinator = MultiProviderBalanceCoordinator(
        registrations: [
            ProviderRegistration(
                descriptor: descriptor,
                makeProvider: { MockBalanceProvider(id: .deepseek, results: []) }
            )
        ],
        credentialStore: InMemoryCredentialStore(),
        preferences: InMemoryProviderPreferencesStore()
    )

    harness.expectEqual(coordinator.descriptor(for: .deepseek), descriptor, "coordinator descriptor comes from registration")
    harness.expectEqual(coordinator.primaryDescriptor, descriptor, "coordinator primary descriptor comes from registration")
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift run APIInquiryCoreTestsRunner
```

Expected: compile failure because `MultiProviderBalanceCoordinator(registrations:...)` does not exist.

- [ ] **Step 3: Implement registration initializer**

Update `MultiProviderBalanceCoordinator` so its primary initializer accepts `registrations: [ProviderRegistration]`, creates each provider from `registration.makeProvider()`, and stores `registration.descriptor` in `ProviderRuntime`.

- [ ] **Step 4: Update app entrypoint**

Change `Sources/APIInquiryApp/APIInquiryApp.swift` from creating providers to passing registrations:

```swift
let registry = BuiltInProviderRegistry.default
let coordinator = MultiProviderBalanceCoordinator(
    registrations: registry.registrations,
    credentialStore: credentialStore,
    preferences: UserDefaultsProviderPreferencesStore(),
    defaultProviderID: registry.defaultProviderID,
    localizedStrings: { LocalizedStrings(language: languageStore.resolvedLanguage) }
)
```

- [ ] **Step 5: Run GREEN**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

Expected: both commands pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift Sources/APIInquiryApp/APIInquiryApp.swift Sources/APIInquiryCoreTestsRunner/MultiProviderBalanceCoordinatorTests.swift
git commit -m "refactor: initialize coordinator from provider registrations"
```

## Task 2: Credential Account Injection

- [ ] **Step 1: Write failing controller test**

Add a test in `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift` proving credential lookup does not come from global provider metadata:

```swift
@MainActor
private static func testRefreshUsesInjectedCredentialAccount(using harness: TestHarness) async {
    let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
    let store = InMemoryCredentialStore(credentialsByAccount: ["custom-account": "custom-key"])
    let controller = BalanceRefreshController(
        provider: provider,
        credentialStore: store,
        credentialAccount: "custom-account"
    )

    await controller.refresh()

    harness.expectEqual(provider.lastAPIKey, "custom-key", "refresh uses injected credential account")
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift run APIInquiryCoreTestsRunner
```

Expected: compile failure because `credentialAccount:` is not an initializer parameter.

- [ ] **Step 3: Implement credential account injection**

Update `BalanceRefreshController`:

```swift
private let credentialAccount: String

public init(
    provider: BalanceProvider,
    credentialStore: CredentialStore,
    credentialAccount: String,
    initialState: BalanceState = .notConfigured,
    refreshInterval: TimeInterval = 300,
    localizedStrings: @escaping () -> LocalizedStrings = { LocalizedStrings(language: .en) }
) {
    self.provider = provider
    self.credentialStore = credentialStore
    self.credentialAccount = credentialAccount
    self.state = initialState
    self.refreshInterval = refreshInterval
    self.localizedStrings = localizedStrings
}
```

In `refresh()`, replace `provider.credentialAccount` with `credentialAccount`.

- [ ] **Step 4: Update coordinator controller creation**

When creating a controller from a registration descriptor:

```swift
BalanceRefreshController(
    provider: provider,
    credentialStore: credentialStore,
    credentialAccount: descriptor.credentialAccount,
    initialState: initialStatesByProviderID[provider.id] ?? .notConfigured,
    localizedStrings: localizedStrings
)
```

- [ ] **Step 5: Update tests and compatibility call sites**

Every direct `BalanceRefreshController(provider:credentialStore:)` call in tests should pass `credentialAccount: ProviderCatalog.default.descriptor(for: provider.id)!.credentialAccount` or a test-specific account string.

- [ ] **Step 6: Run GREEN and commit**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift Sources/APIInquiryCore/Refresh/MultiProviderBalanceCoordinator.swift Sources/APIInquiryCoreTestsRunner
git commit -m "refactor: inject provider credential account into refresh controller"
```

## Task 3: Remove BalanceProvider Metadata Extension

- [ ] **Step 1: Delete metadata convenience properties**

In `Sources/APIInquiryCore/Providers/BalanceProvider.swift`, remove:

```swift
var descriptor: ProviderDescriptor
var displayName: String
var menuPrefix: String
var credentialAccount: String
var homepageURL: URL
var supportsConsoleCredentialManagement: Bool
```

Keep `fetchBalance(apiKey:)`.

- [ ] **Step 2: Remove provider-based formatter overloads**

Delete `primaryDisplayParts(provider:state:strings:)` from `ProviderValueFormatter` and `ProviderDisplayFormatter` unless a current call site still uses it.

- [ ] **Step 3: Update build errors**

Any compile error should be fixed by passing or reading `ProviderDescriptor` from coordinator/runtime, not by reintroducing global catalog lookup.

- [ ] **Step 4: Run verification and commit**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/Providers/BalanceProvider.swift Sources/APIInquiryCore/Formatting
git commit -m "refactor: keep balance providers metadata-free"
```

## Task 4: Clean ViewModel Legacy Initializers

- [ ] **Step 1: Remove or deprecate provider/controller initializers**

Prefer removing these initializers if tests can be updated in the same task:

```swift
MenuBarBalanceViewModel(provider:credentialStore:controller:...)
UsageConsoleViewModel(provider:credentialStore:controller:...)
```

If removal causes too much churn, mark them deprecated and route them through explicit `ProviderRegistration`.

- [ ] **Step 2: Update tests to create coordinator helpers**

Test helpers should build:

```swift
MultiProviderBalanceCoordinator(
    registrations: [
        ProviderRegistration(
            descriptor: ProviderCatalog.default.descriptor(for: provider.id)!,
            makeProvider: { provider }
        )
    ],
    credentialStore: credentialStore,
    preferences: InMemoryProviderPreferencesStore(
        addedProviderIDs: [provider.id],
        primaryProviderID: provider.id
    ),
    defaultProviderID: provider.id,
    controllersByProviderID: [provider.id: controller]
)
```

- [ ] **Step 3: Remove dead code**

Delete `UsageConsoleViewModel.hasConfiguredCredential(in:account:)` if `rg "hasConfiguredCredential"` only finds its declaration.

- [ ] **Step 4: Run verification and commit**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCore/ViewModels Sources/APIInquiryCoreTestsRunner
git commit -m "refactor: remove legacy provider view model entrypoints"
```

## Task 5: Simplify Test Mocks

- [ ] **Step 1: Simplify `MockBalanceProvider`**

In `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`, reduce `MockBalanceProvider` to protocol-required behavior:

```swift
final class MockBalanceProvider: BalanceProvider {
    let id: ProviderID
    private var results: [Result<ProviderSnapshot, Error>]
    private(set) var fetchCount = 0
    private(set) var lastAPIKey: String?

    init(id: ProviderID = .deepseek, results: [Result<ProviderSnapshot, Error>]) {
        self.id = id
        self.results = results
    }

    func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        fetchCount += 1
        lastAPIKey = apiKey

        guard !results.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }
        return try results.removeFirst().get()
    }
}
```

- [ ] **Step 2: Update tests that previously passed mock metadata**

Replace mock metadata arguments with descriptor/registration setup. Metadata assertions should use `ProviderDescriptor`, `ProviderRegistration`, or coordinator descriptors.

- [ ] **Step 3: Run verification and commit**

```bash
swift run APIInquiryCoreTestsRunner
swift build
git add Sources/APIInquiryCoreTestsRunner
git commit -m "test: remove metadata from mock providers"
```

## Final Verification

- [ ] Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
rg -n "ProviderCatalog\\.default|provider\\.descriptor|provider\\.credentialAccount|singleProvider|singleController|hasConfiguredCredential|displayName: \"DeepSeek\"|menuPrefix: \"DS\"" Sources/APIInquiryCore Sources/APIInquiryApp Sources/APIInquiryCoreTestsRunner
```

- [ ] Inspect remaining `ProviderCatalog.default` hits. Accept only catalog tests, catalog construction, and explicitly documented compatibility paths.
- [ ] Confirm the app still launches and current UI behavior is unchanged.
- [ ] Request final code quality review.
- [ ] Commit any final cleanup.
