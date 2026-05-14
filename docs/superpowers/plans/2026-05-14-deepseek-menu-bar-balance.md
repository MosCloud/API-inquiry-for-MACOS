# DeepSeek Menu Bar Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 13+ menu bar app that securely stores a DeepSeek API key, refreshes the official DeepSeek balance API every 5 minutes, and shows the current balance in the menu bar.

**Architecture:** Use a Swift Package with a testable `APIInquiryCore` library and a thin `APIInquiryApp` SwiftUI executable. Core owns provider abstractions, DeepSeek decoding, Keychain storage, refresh orchestration, and formatting; the app target owns `MenuBarExtra` UI and macOS actions.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, URLSession, Security/Keychain, Swift Package Manager, local Swift executable test runner.

---

## Testing Environment Amendment

This machine has CommandLineTools but no full Xcode installation. Root-cause checks showed that `xcrun --find xctest` fails, no `XCTest.framework` is installed, and Swift's `Testing` module is unavailable. Therefore this project uses a local executable test runner instead of XCTest.

All task sections below have been updated to use this runner-based flow.

Use these rules for implementation tasks:

- Test runner target: `APIInquiryCoreTestsRunner`.
- Test runner files live under `Sources/APIInquiryCoreTestsRunner/`.
- Add behavior tests as functions called from `Sources/APIInquiryCoreTestsRunner/main.swift`.
- Use the local `TestHarness` helpers instead of XCTest assertions.
- Run tests with `swift run APIInquiryCoreTestsRunner`.
- Keep using `swift build` for compile verification.

## File Structure

- Create `Package.swift`: Swift Package definition with a core library and local test runner executable; the app executable target is added when the UI entry point exists.
- Create `Sources/APIInquiryCore/Models/BalanceModels.swift`: provider id, balance snapshot, balance state, and display mode models.
- Create `Sources/APIInquiryCore/Providers/BalanceProvider.swift`: provider protocol and provider error definitions.
- Create `Sources/APIInquiryCore/Networking/HTTPClient.swift`: injectable HTTP client abstraction plus URLSession implementation.
- Create `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`: DeepSeek `/user/balance` request, response decoding, CNY preference, and error mapping.
- Create `Sources/APIInquiryCore/Security/CredentialStore.swift`: credential store protocol and Keychain-backed implementation.
- Create `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`: launch/manual/timer refresh coordinator.
- Create `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`: menu title formatting, setup state, settings actions, and UI-facing state.
- Create `Sources/APIInquiryApp/APIInquiryApp.swift`: SwiftUI `MenuBarExtra` app entry point.
- Create `Sources/APIInquiryApp/MenuBarContentView.swift`: minimal expanded panel and API key settings UI.
- Create `Scripts/build-local-app.sh`: local `.app` bundle builder with `LSUIElement=true`.
- Create `Sources/APIInquiryCoreTestsRunner/TestHarness.swift`: lightweight assertion harness for local verification.
- Create `Sources/APIInquiryCoreTestsRunner/TestHarnessTests.swift`: self-checks that the runner fails if no expectations are executed.
- Create `Sources/APIInquiryCoreTestsRunner/main.swift`: async entry point that runs all core behavior tests.
- Create `Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift`: provider decoding and error tests.
- Create `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`: refresh state and last-snapshot tests.
- Create `Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`: title, panel text, and key visibility tests.
- Create `Sources/APIInquiryCoreTestsRunner/KeychainCredentialStoreTests.swift`: save/load/replace/delete tests with an isolated service name.

---

### Task 1: Package Skeleton And Core Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/APIInquiryCore/Models/BalanceModels.swift`
- Create: `Sources/APIInquiryCore/Providers/BalanceProvider.swift`
- Create: `Sources/APIInquiryCore/Networking/HTTPClient.swift`
- Test: `swift build` compiles the initial core target; behavior tests run through `APIInquiryCoreTestsRunner` once that runner exists.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "APIInquiry",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "APIInquiryCore",
            targets: ["APIInquiryCore"]
        ),
        .executable(
            name: "APIInquiryCoreTestsRunner",
            targets: ["APIInquiryCoreTestsRunner"]
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .executableTarget(
            name: "APIInquiryCoreTestsRunner",
            dependencies: ["APIInquiryCore"]
        )
    ]
)
```

- [ ] **Step 2: Create core balance models**

Create `Sources/APIInquiryCore/Models/BalanceModels.swift`:

```swift
import Foundation

public enum ProviderID: String, Equatable {
    case deepseek
}

public enum MenuBarDisplayMode: Equatable {
    case text
    case iconAndText
}

public struct BalanceSnapshot: Equatable {
    public let providerID: ProviderID
    public let totalBalance: Decimal
    public let currency: String
    public let isAvailable: Bool
    public let grantedBalance: Decimal?
    public let toppedUpBalance: Decimal?
    public let fetchedAt: Date

    public init(
        providerID: ProviderID,
        totalBalance: Decimal,
        currency: String,
        isAvailable: Bool,
        grantedBalance: Decimal?,
        toppedUpBalance: Decimal?,
        fetchedAt: Date
    ) {
        self.providerID = providerID
        self.totalBalance = totalBalance
        self.currency = currency
        self.isAvailable = isAvailable
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.fetchedAt = fetchedAt
    }
}

public enum BalanceState: Equatable {
    case notConfigured
    case loading(last: BalanceSnapshot?)
    case loaded(BalanceSnapshot)
    case failed(message: String, last: BalanceSnapshot?)

    public var lastSnapshot: BalanceSnapshot? {
        switch self {
        case .notConfigured:
            return nil
        case .loading(let last):
            return last
        case .loaded(let snapshot):
            return snapshot
        case .failed(_, let last):
            return last
        }
    }
}
```

- [ ] **Step 3: Create provider protocol and user-facing errors**

Create `Sources/APIInquiryCore/Providers/BalanceProvider.swift`:

```swift
import Foundation

public protocol BalanceProvider {
    var id: ProviderID { get }
    var displayName: String { get }
    var menuPrefix: String { get }
    var credentialAccount: String { get }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot
}

public enum BalanceProviderError: Error, Equatable, LocalizedError {
    case invalidURL
    case authenticationFailed
    case rateLimited
    case serverError(statusCode: Int)
    case missingBalanceInfo
    case invalidBalanceAmount(String)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Balance API URL is invalid."
        case .authenticationFailed:
            return "API key may be invalid. Replace or delete it in settings."
        case .rateLimited:
            return "Balance API rate limit reached. Try again shortly."
        case .serverError(let statusCode):
            return "Balance API returned HTTP \(statusCode). Try again shortly."
        case .missingBalanceInfo:
            return "Balance API did not return balance information."
        case .invalidBalanceAmount:
            return "Balance API returned an invalid balance amount."
        case .decodingFailed:
            return "Balance API response could not be decoded."
        }
    }
}
```

- [ ] **Step 4: Create injectable HTTP client**

Create `Sources/APIInquiryCore/Networking/HTTPClient.swift`:

```swift
import Foundation

public struct HTTPResponse: Equatable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> HTTPResponse
}

public enum HTTPClientError: Error, Equatable, LocalizedError {
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        }
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return HTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
}
```

- [ ] **Step 5: Run package resolution and compile check**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 6: Commit package skeleton**

```bash
git add Package.swift Sources/APIInquiryCore
git commit -m "chore: add swift package skeleton and balance models"
```

---

### Task 2: DeepSeek Balance Provider

**Files:**
- Create: `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`
- Create: `Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift`
- Create: `Sources/APIInquiryCoreTestsRunner/TestHarnessTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/TestHarness.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/main.swift` if the new test suite needs to be registered

- [ ] **Step 1: Write failing provider tests in the local runner**

Create `Sources/APIInquiryCoreTestsRunner/DeepSeekBalanceProviderTests.swift` using the existing `TestHarness`, not XCTest. Cover these behaviors with fake API keys and `MockHTTPClient` only:

- CNY is preferred when multiple currencies are returned.
- The first returned currency is used when CNY is absent.
- HTTP 401 maps to `.authenticationFailed`.
- HTTP 429 maps to `.rateLimited`.
- Invalid `total_balance` maps to `.invalidBalanceAmount(...)`, including fully nonnumeric strings, trailing junk such as `1.23abc`, and grouping separators such as `1,234.56`.
- The local `TestHarness` fails instead of reporting `PASS: 0 expectations` when no expectations are executed.

Register the test suite from `Sources/APIInquiryCoreTestsRunner/main.swift` if it is not already called.

- [ ] **Step 2: Run tests to verify the red state**

Run:

```bash
swift run APIInquiryCoreTestsRunner
```

Expected: FAIL because `DeepSeekBalanceProvider` does not exist yet.

- [ ] **Step 3: Implement DeepSeek provider**

Create `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift` with `DeepSeekBalanceProvider: BalanceProvider`. It must use the injected `HTTPClient`, send `GET https://api.deepseek.com/user/balance` by default, attach `Authorization: Bearer <apiKey>`, decode `is_available` and `balance_infos`, prefer CNY, fall back to the first currency, preserve optional granted and topped-up balances, parse decimals with `Locale(identifier: "en_US_POSIX")`, and map status/error cases as specified in the design.

- [ ] **Step 4: Run provider tests and build**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

Expected: both PASS.

- [ ] **Step 5: Commit provider and runner tests**

```bash
git add Package.swift Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift Sources/APIInquiryCoreTestsRunner
git commit -m "feat: add deepseek balance provider"
```

---

### Task 3: Secure Credential Storage

**Files:**
- Create: `Sources/APIInquiryCore/Security/CredentialStore.swift`
- Create: `Sources/APIInquiryCoreTestsRunner/KeychainCredentialStoreTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/main.swift`

- [ ] **Step 1: Add failing credential-store runner tests**

Add runner tests for saving, loading, replacing, and deleting a fake API key with an isolated Keychain service name. Use the local `TestHarness`; do not use XCTest or a real key.

- [ ] **Step 2: Verify red state**

Run `swift run APIInquiryCoreTestsRunner`.

Expected: FAIL because `KeychainCredentialStore` does not exist.

- [ ] **Step 3: Implement credential storage**

Create `CredentialStore`, `CredentialStoreError`, `KeychainCredentialStore`, and `InMemoryCredentialStore`. Store credentials only through macOS Keychain for production and keep the in-memory store for tests/view models.

- [ ] **Step 4: Verify green state and build**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

Expected: both PASS.

- [ ] **Step 5: Commit credential storage**

```bash
git add Sources/APIInquiryCore/Security Sources/APIInquiryCoreTestsRunner
git commit -m "feat: store api keys in keychain"
```

---

### Task 4: Refresh Controller And View Model

**Files:**
- Create: `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`
- Create: `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
- Create: `Sources/APIInquiryCoreTestsRunner/BalanceRefreshControllerTests.swift`
- Create: `Sources/APIInquiryCoreTestsRunner/MenuBarBalanceViewModelTests.swift`
- Modify: `Sources/APIInquiryCoreTestsRunner/main.swift`

- [ ] **Step 1: Add failing refresh and view-model runner tests**

Add runner tests for missing credential, successful refresh, overlapping refresh prevention, failure preserving the last snapshot, loaded menu title formatting, configured-key placeholder title, failed-state title preservation, panel balance text, status text, and API key input clearing after save/configure. Use mock providers and fake keys only.

- [ ] **Step 2: Verify red state**

Run `swift run APIInquiryCoreTestsRunner`.

Expected: FAIL because `BalanceRefreshController` and `MenuBarBalanceViewModel` do not exist.

- [ ] **Step 3: Implement refresh controller**

Implement a `@MainActor` observable controller that reads credentials, prevents overlapping refreshes, preserves last successful snapshots, exposes `BalanceState`, supports manual refresh, supports a 300-second auto-refresh loop, and maps errors to user-facing messages without exposing secrets.

- [ ] **Step 4: Implement menu bar view model**

Implement menu title formatting as `DS ¥68.6`, panel text as `¥68.65 CNY`, setup/error/status text, API key save/replace/delete commands, and production wiring to `DeepSeekBalanceProvider` plus `KeychainCredentialStore`.

- [ ] **Step 5: Verify green state and build**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
```

Expected: both PASS.

- [ ] **Step 6: Commit refresh and view model**

```bash
git add Sources/APIInquiryCore/Refresh Sources/APIInquiryCore/ViewModels Sources/APIInquiryCoreTestsRunner
git commit -m "feat: coordinate balance refresh state"
```

---

### Task 5: Native Menu Bar UI And Local App Bundle

**Files:**
- Modify: `Package.swift`
- Create: `Sources/APIInquiryApp/APIInquiryApp.swift`
- Create: `Sources/APIInquiryApp/MenuBarContentView.swift`
- Create: `Scripts/build-local-app.sh`

- [ ] **Step 1: Add the app executable target**

Update `Package.swift` to keep `APIInquiryCore` and `APIInquiryCoreTestsRunner`, and add executable product/target `APIInquiryApp` depending on `APIInquiryCore`.

- [ ] **Step 2: Create SwiftUI menu bar app**

Create `APIInquiryApp.swift` with `MenuBarExtra(viewModel.menuBarTitle)`, `.menuBarExtraStyle(.window)`, and accessory activation policy.

- [ ] **Step 3: Create minimal expanded panel**

Create `MenuBarContentView.swift` with DeepSeek label, large balance, status, last refresh text, refresh icon button, secure API key entry, replace/delete key actions, Open Console, and Quit. Keep the UI minimal; do not add charts.

- [ ] **Step 4: Create local app bundle script**

Create `Scripts/build-local-app.sh` that runs `swift build`, builds `.build/APIInquiry.app`, copies the executable, and writes an `Info.plist` with `LSUIElement=true`.

- [ ] **Step 5: Verify runner, build, and app bundle**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

Expected: runner and build pass, and the script creates `.build/APIInquiry.app`.

- [ ] **Step 6: Commit app UI and bundle script**

```bash
git add Package.swift Sources/APIInquiryApp Scripts/build-local-app.sh
git commit -m "feat: add native menu bar app"
```

---

### Task 6: Full Verification And Manual Run Notes

**Files:**
- Create: `README.md`
- Create: `README_zh.md`

- [ ] **Step 1: Create English README**

Document requirements, `swift run APIInquiryCoreTestsRunner`, `Scripts/build-local-app.sh`, generated `.build/APIInquiry.app`, and Keychain security behavior.

- [ ] **Step 2: Create Chinese README**

Create the synchronized Chinese version with the same commands and security notes.

- [ ] **Step 3: Run full automated verification**

Run:

```bash
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

Expected: all commands pass.

- [ ] **Step 4: Launch for manual testing**

Run:

```bash
open .build/APIInquiry.app
```

Expected: macOS launches the menu bar app. Request approval if the sandbox blocks `open`.

- [ ] **Step 5: Complete manual checks**

Check no-key setup state, saving a real key locally, menu title balance formatting, panel balance formatting, refresh button, replace/delete key behavior, console link, and quit.

- [ ] **Step 6: Commit README files**

```bash
git add README.md README_zh.md
git commit -m "docs: add local run instructions"
```

- [ ] **Step 7: Final verification before handoff**

Run:

```bash
git status --short
swift run APIInquiryCoreTestsRunner
swift build
Scripts/build-local-app.sh
```

Expected:

- `git status --short` prints no tracked source changes.
- `swift run APIInquiryCoreTestsRunner` passes.
- `swift build` passes.
- `Scripts/build-local-app.sh` builds `.build/APIInquiry.app`.

---

## Plan Self-Review

- Spec coverage: balance-only DeepSeek menu bar app, 5-minute refresh, manual refresh, Keychain storage, minimal panel, provider abstraction, no first-release charts, and local source deliverable are all covered.
- Placeholder scan: the plan uses exact files, code blocks, commands, expected results, and commit messages.
- Type consistency: `ProviderID`, `BalanceSnapshot`, `BalanceState`, `BalanceProvider`, `HTTPClient`, `CredentialStore`, `BalanceRefreshController`, and `MenuBarBalanceViewModel` names are consistent across tasks.
