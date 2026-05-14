# DeepSeek Menu Bar Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 13+ menu bar app that securely stores a DeepSeek API key, refreshes the official DeepSeek balance API every 5 minutes, and shows the current balance in the menu bar.

**Architecture:** Use a Swift Package with a testable `APIInquiryCore` library and a thin `APIInquiryApp` SwiftUI executable. Core owns provider abstractions, DeepSeek decoding, Keychain storage, refresh orchestration, and formatting; the app target owns `MenuBarExtra` UI and macOS actions.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, URLSession, Security/Keychain, XCTest, Swift Package Manager.

---

## File Structure

- Create `Package.swift`: Swift Package definition with a core library and test target first; the app executable target is added when the UI entry point exists.
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
- Create `Tests/APIInquiryCoreTests/DeepSeekBalanceProviderTests.swift`: provider decoding and error tests.
- Create `Tests/APIInquiryCoreTests/BalanceRefreshControllerTests.swift`: refresh state and last-snapshot tests.
- Create `Tests/APIInquiryCoreTests/MenuBarBalanceViewModelTests.swift`: title, panel text, and key visibility tests.
- Create `Tests/APIInquiryCoreTests/KeychainCredentialStoreTests.swift`: save/load/replace/delete tests with an isolated service name.

---

### Task 1: Package Skeleton And Core Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/APIInquiryCore/Models/BalanceModels.swift`
- Create: `Sources/APIInquiryCore/Providers/BalanceProvider.swift`
- Create: `Sources/APIInquiryCore/Networking/HTTPClient.swift`
- Test: `swift test` initially compiles the empty test target after later tests are added.

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
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .testTarget(
            name: "APIInquiryCoreTests",
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
            return "DeepSeek balance URL is invalid."
        case .authenticationFailed:
            return "API key may be invalid. Replace or delete it in settings."
        case .rateLimited:
            return "DeepSeek rate limit reached. Try again shortly."
        case .serverError(let statusCode):
            return "DeepSeek returned HTTP \(statusCode). Try again shortly."
        case .missingBalanceInfo:
            return "DeepSeek did not return balance information."
        case .invalidBalanceAmount(let value):
            return "DeepSeek returned an invalid balance amount: \(value)."
        case .decodingFailed:
            return "DeepSeek balance response could not be decoded."
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

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BalanceProviderError.serverError(statusCode: -1)
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
- Create: `Tests/APIInquiryCoreTests/DeepSeekBalanceProviderTests.swift`

- [ ] **Step 1: Write failing provider tests**

Create `Tests/APIInquiryCoreTests/DeepSeekBalanceProviderTests.swift`:

```swift
import Foundation
import XCTest
@testable import APIInquiryCore

final class DeepSeekBalanceProviderTests: XCTestCase {
    func testFetchBalancePrefersCNY() async throws {
        let body = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "1.25",
              "granted_balance": "0.25",
              "topped_up_balance": "1.00"
            },
            {
              "currency": "CNY",
              "total_balance": "68.65",
              "granted_balance": "8.65",
              "topped_up_balance": "60.00"
            }
          ]
        }
        """.data(using: .utf8)!
        let client = MockHTTPClient(response: HTTPResponse(data: body, statusCode: 200))
        let provider = DeepSeekBalanceProvider(httpClient: client, now: { Date(timeIntervalSince1970: 100) })

        let snapshot = try await provider.fetchBalance(apiKey: "test-key")

        XCTAssertEqual(snapshot.providerID, .deepseek)
        XCTAssertEqual(snapshot.currency, "CNY")
        XCTAssertEqual(snapshot.totalBalance, Decimal(string: "68.65"))
        XCTAssertEqual(snapshot.grantedBalance, Decimal(string: "8.65"))
        XCTAssertEqual(snapshot.toppedUpBalance, Decimal(string: "60.00"))
        XCTAssertTrue(snapshot.isAvailable)
        XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(client.lastRequest?.url?.absoluteString, "https://api.deepseek.com/user/balance")
    }

    func testFetchBalanceFallsBackToFirstCurrencyWhenCNYIsMissing() async throws {
        let body = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "2.50",
              "granted_balance": "0.00",
              "topped_up_balance": "2.50"
            }
          ]
        }
        """.data(using: .utf8)!
        let provider = DeepSeekBalanceProvider(
            httpClient: MockHTTPClient(response: HTTPResponse(data: body, statusCode: 200)),
            now: { Date(timeIntervalSince1970: 200) }
        )

        let snapshot = try await provider.fetchBalance(apiKey: "test-key")

        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.totalBalance, Decimal(string: "2.50"))
    }

    func testAuthenticationFailureMapsToProviderError() async {
        let provider = DeepSeekBalanceProvider(
            httpClient: MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401)),
            now: Date.init
        )

        do {
            _ = try await provider.fetchBalance(apiKey: "bad-key")
            XCTFail("Expected authentication error")
        } catch {
            XCTAssertEqual(error as? BalanceProviderError, .authenticationFailed)
        }
    }

    func testRateLimitMapsToProviderError() async {
        let provider = DeepSeekBalanceProvider(
            httpClient: MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429)),
            now: Date.init
        )

        do {
            _ = try await provider.fetchBalance(apiKey: "test-key")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? BalanceProviderError, .rateLimited)
        }
    }

    func testInvalidAmountMapsToProviderError() async {
        let body = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "not-a-number",
              "granted_balance": "0.00",
              "topped_up_balance": "0.00"
            }
          ]
        }
        """.data(using: .utf8)!
        let provider = DeepSeekBalanceProvider(
            httpClient: MockHTTPClient(response: HTTPResponse(data: body, statusCode: 200)),
            now: Date.init
        )

        do {
            _ = try await provider.fetchBalance(apiKey: "test-key")
            XCTFail("Expected invalid amount error")
        } catch {
            XCTAssertEqual(error as? BalanceProviderError, .invalidBalanceAmount("not-a-number"))
        }
    }
}

private final class MockHTTPClient: HTTPClient {
    let response: HTTPResponse
    private(set) var lastRequest: URLRequest?

    init(response: HTTPResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPResponse {
        lastRequest = request
        return response
    }
}
```

- [ ] **Step 2: Run provider tests to verify failure**

Run:

```bash
swift test --filter DeepSeekBalanceProviderTests
```

Expected: FAIL because `DeepSeekBalanceProvider` does not exist.

- [ ] **Step 3: Implement DeepSeek provider**

Create `Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift`:

```swift
import Foundation

public final class DeepSeekBalanceProvider: BalanceProvider {
    public let id: ProviderID = .deepseek
    public let displayName = "DeepSeek"
    public let menuPrefix = "DS"
    public let credentialAccount = "deepseek-api-key"

    private let baseURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date

    public init(
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        let url = baseURL.appending(path: "user/balance")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return try decodeBalance(from: response.data)
        case 401:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeBalance(from data: Data) throws -> BalanceSnapshot {
        let response: DeepSeekBalanceResponse
        do {
            response = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        guard let selected = response.balanceInfos.first(where: { $0.currency == "CNY" }) ?? response.balanceInfos.first else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return BalanceSnapshot(
            providerID: .deepseek,
            totalBalance: try decimal(from: selected.totalBalance),
            currency: selected.currency,
            isAvailable: response.isAvailable,
            grantedBalance: try selected.grantedBalance.map(decimal(from:)),
            toppedUpBalance: try selected.toppedUpBalance.map(decimal(from:)),
            fetchedAt: now()
        )
    }

    private func decimal(from value: String) throws -> Decimal {
        if let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) {
            return decimal
        }
        throw BalanceProviderError.invalidBalanceAmount(value)
    }
}

private struct DeepSeekBalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct DeepSeekBalanceInfo: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String?
    let toppedUpBalance: String?

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}
```

- [ ] **Step 4: Run provider tests**

Run:

```bash
swift test --filter DeepSeekBalanceProviderTests
```

Expected: PASS for all provider tests.

- [ ] **Step 5: Commit provider**

```bash
git add Sources/APIInquiryCore/Providers/DeepSeekBalanceProvider.swift Tests/APIInquiryCoreTests/DeepSeekBalanceProviderTests.swift
git commit -m "feat: add deepseek balance provider"
```

---

### Task 3: Secure Credential Storage

**Files:**
- Create: `Sources/APIInquiryCore/Security/CredentialStore.swift`
- Create: `Tests/APIInquiryCoreTests/KeychainCredentialStoreTests.swift`

- [ ] **Step 1: Write failing credential tests**

Create `Tests/APIInquiryCoreTests/KeychainCredentialStoreTests.swift`:

```swift
import XCTest
@testable import APIInquiryCore

final class KeychainCredentialStoreTests: XCTestCase {
    func testSaveLoadReplaceDeleteCredential() throws {
        let service = "com.api-inquiry.tests.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        let account = "deepseek-api-key"

        try store.saveCredential("first-secret", account: account)
        XCTAssertEqual(try store.loadCredential(account: account), "first-secret")

        try store.saveCredential("second-secret", account: account)
        XCTAssertEqual(try store.loadCredential(account: account), "second-secret")

        try store.deleteCredential(account: account)
        XCTAssertNil(try store.loadCredential(account: account))
    }
}
```

- [ ] **Step 2: Run credential tests to verify failure**

Run:

```bash
swift test --filter KeychainCredentialStoreTests
```

Expected: FAIL because `KeychainCredentialStore` does not exist.

- [ ] **Step 3: Implement credential store**

Create `Sources/APIInquiryCore/Security/CredentialStore.swift`:

```swift
import Foundation
import Security

public protocol CredentialStore {
    func loadCredential(account: String) throws -> String?
    func saveCredential(_ credential: String, account: String) throws
    func deleteCredential(account: String) throws
}

public enum CredentialStoreError: Error, Equatable, LocalizedError {
    case invalidData
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Stored credential could not be read."
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

public final class KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "com.api-inquiry.credentials") {
        self.service = service
    }

    public func loadCredential(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let credential = String(data: data, encoding: .utf8)
        else {
            throw CredentialStoreError.invalidData
        }
        return credential
    }

    public func saveCredential(_ credential: String, account: String) throws {
        let data = Data(credential.utf8)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func deleteCredential(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecItemNotFound {
            return
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class InMemoryCredentialStore: CredentialStore {
    private var values: [String: String] = [:]

    public init(initialValues: [String: String] = [:]) {
        self.values = initialValues
    }

    public func loadCredential(account: String) throws -> String? {
        values[account]
    }

    public func saveCredential(_ credential: String, account: String) throws {
        values[account] = credential
    }

    public func deleteCredential(account: String) throws {
        values.removeValue(forKey: account)
    }
}
```

- [ ] **Step 4: Run credential tests**

Run:

```bash
swift test --filter KeychainCredentialStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit credential storage**

```bash
git add Sources/APIInquiryCore/Security/CredentialStore.swift Tests/APIInquiryCoreTests/KeychainCredentialStoreTests.swift
git commit -m "feat: store api keys in keychain"
```

---

### Task 4: Refresh Controller And View Model

**Files:**
- Create: `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`
- Create: `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`
- Create: `Tests/APIInquiryCoreTests/BalanceRefreshControllerTests.swift`
- Create: `Tests/APIInquiryCoreTests/MenuBarBalanceViewModelTests.swift`

- [ ] **Step 1: Write failing refresh controller tests**

Create `Tests/APIInquiryCoreTests/BalanceRefreshControllerTests.swift`:

```swift
import XCTest
@testable import APIInquiryCore

@MainActor
final class BalanceRefreshControllerTests: XCTestCase {
    func testRefreshWithoutCredentialShowsNotConfigured() async {
        let controller = BalanceRefreshController(
            provider: MockProvider(snapshot: .sample),
            credentialStore: InMemoryCredentialStore()
        )

        await controller.refresh()

        XCTAssertEqual(controller.state, .notConfigured)
    }

    func testRefreshLoadsSnapshot() async throws {
        let store = InMemoryCredentialStore(initialValues: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(
            provider: MockProvider(snapshot: .sample),
            credentialStore: store
        )

        await controller.refresh()

        XCTAssertEqual(controller.state, .loaded(.sample))
    }

    func testFailurePreservesLastSnapshot() async throws {
        let store = InMemoryCredentialStore(initialValues: ["deepseek-api-key": "test-key"])
        let provider = ToggleProvider(success: .sample, failure: BalanceProviderError.rateLimited)
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        provider.shouldFail = true
        await controller.refresh()

        XCTAssertEqual(controller.state, .failed(message: "DeepSeek rate limit reached. Try again shortly.", last: .sample))
    }
}

private extension BalanceSnapshot {
    static let sample = BalanceSnapshot(
        providerID: .deepseek,
        totalBalance: Decimal(string: "68.65")!,
        currency: "CNY",
        isAvailable: true,
        grantedBalance: nil,
        toppedUpBalance: nil,
        fetchedAt: Date(timeIntervalSince1970: 100)
    )
}

private final class MockProvider: BalanceProvider {
    let id: ProviderID = .deepseek
    let displayName = "DeepSeek"
    let menuPrefix = "DS"
    let credentialAccount = "deepseek-api-key"
    let snapshot: BalanceSnapshot

    init(snapshot: BalanceSnapshot) {
        self.snapshot = snapshot
    }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        snapshot
    }
}

private final class ToggleProvider: BalanceProvider {
    let id: ProviderID = .deepseek
    let displayName = "DeepSeek"
    let menuPrefix = "DS"
    let credentialAccount = "deepseek-api-key"
    let success: BalanceSnapshot
    let failure: Error
    var shouldFail = false

    init(success: BalanceSnapshot, failure: Error) {
        self.success = success
        self.failure = failure
    }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        if shouldFail {
            throw failure
        }
        return success
    }
}
```

- [ ] **Step 2: Write failing view model tests**

Create `Tests/APIInquiryCoreTests/MenuBarBalanceViewModelTests.swift`:

```swift
import XCTest
@testable import APIInquiryCore

@MainActor
final class MenuBarBalanceViewModelTests: XCTestCase {
    func testMenuBarTitleFormatsLoadedBalance() {
        let viewModel = MenuBarBalanceViewModel.makePreview(state: .loaded(.sample))

        XCTAssertEqual(viewModel.menuBarTitle, "DS ¥68.6")
        XCTAssertEqual(viewModel.panelBalanceText, "¥68.65 CNY")
        XCTAssertEqual(viewModel.statusText, "Available")
    }

    func testMenuBarTitleKeepsLastSnapshotOnFailure() {
        let viewModel = MenuBarBalanceViewModel.makePreview(
            state: .failed(message: "Network unavailable.", last: .sample)
        )

        XCTAssertEqual(viewModel.menuBarTitle, "DS ¥68.6")
        XCTAssertEqual(viewModel.statusText, "Network unavailable.")
    }

    func testSavedKeyIsNeverDisplayed() {
        let viewModel = MenuBarBalanceViewModel.makePreview(state: .notConfigured)
        viewModel.apiKeyInput = "secret-key"
        viewModel.markKeyConfiguredForTesting()

        XCTAssertTrue(viewModel.apiKeyInput.isEmpty)
        XCTAssertEqual(viewModel.keyStatusText, "API key configured")
    }
}

private extension BalanceSnapshot {
    static let sample = BalanceSnapshot(
        providerID: .deepseek,
        totalBalance: Decimal(string: "68.65")!,
        currency: "CNY",
        isAvailable: true,
        grantedBalance: nil,
        toppedUpBalance: nil,
        fetchedAt: Date(timeIntervalSince1970: 100)
    )
}
```

- [ ] **Step 3: Run refresh and view model tests to verify failure**

Run:

```bash
swift test --filter BalanceRefreshControllerTests
swift test --filter MenuBarBalanceViewModelTests
```

Expected: FAIL because the controller and view model do not exist.

- [ ] **Step 4: Implement refresh controller**

Create `Sources/APIInquiryCore/Refresh/BalanceRefreshController.swift`:

```swift
import Combine
import Foundation

@MainActor
public final class BalanceRefreshController: ObservableObject {
    @Published public private(set) var state: BalanceState = .notConfigured

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private var isRefreshing = false
    private var timerTask: Task<Void, Never>?

    public init(provider: BalanceProvider, credentialStore: CredentialStore) {
        self.provider = provider
        self.credentialStore = credentialStore
    }

    deinit {
        timerTask?.cancel()
    }

    public func refresh() async {
        if isRefreshing {
            return
        }

        let last = state.lastSnapshot
        let apiKey: String?
        do {
            apiKey = try credentialStore.loadCredential(account: provider.credentialAccount)
        } catch {
            state = .failed(message: "Could not read API key from Keychain.", last: last)
            return
        }

        guard let apiKey, !apiKey.isEmpty else {
            state = .notConfigured
            return
        }

        isRefreshing = true
        state = .loading(last: last)
        defer { isRefreshing = false }

        do {
            let snapshot = try await provider.fetchBalance(apiKey: apiKey)
            state = .loaded(snapshot)
        } catch {
            state = .failed(message: Self.message(for: error), last: last)
        }
    }

    public func startAutoRefresh(intervalSeconds: UInt64 = 300) {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                await self.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func saveCredential(_ credential: String) throws {
        try credentialStore.saveCredential(credential, account: provider.credentialAccount)
    }

    public func deleteCredential() throws {
        try credentialStore.deleteCredential(account: provider.credentialAccount)
        state = .notConfigured
    }

    static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return "Refresh failed. Try again shortly."
    }
}
```

- [ ] **Step 5: Implement menu bar view model**

Create `Sources/APIInquiryCore/ViewModels/MenuBarBalanceViewModel.swift`:

```swift
import Combine
import Foundation

@MainActor
public final class MenuBarBalanceViewModel: ObservableObject {
    @Published public var apiKeyInput = ""
    @Published public var isEditingKey = false
    @Published public private(set) var state: BalanceState

    private let provider: BalanceProvider
    private let controller: BalanceRefreshController
    private let displayMode: MenuBarDisplayMode

    public init(
        provider: BalanceProvider,
        controller: BalanceRefreshController,
        displayMode: MenuBarDisplayMode = .text
    ) {
        self.provider = provider
        self.controller = controller
        self.displayMode = displayMode
        self.state = controller.state
    }

    public static func production() -> MenuBarBalanceViewModel {
        let provider = DeepSeekBalanceProvider()
        let store = KeychainCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)
        return MenuBarBalanceViewModel(provider: provider, controller: controller)
    }

    public static func makePreview(state: BalanceState) -> MenuBarBalanceViewModel {
        let provider = DeepSeekBalanceProvider(httpClient: PreviewHTTPClient())
        let store = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)
        let viewModel = MenuBarBalanceViewModel(provider: provider, controller: controller)
        viewModel.state = state
        return viewModel
    }

    public var menuBarTitle: String {
        guard let snapshot = state.lastSnapshot else {
            return "\(provider.menuPrefix) --"
        }
        return "\(provider.menuPrefix) \(format(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 1, includeCode: false))"
    }

    public var panelBalanceText: String {
        guard let snapshot = state.lastSnapshot else {
            return "--"
        }
        return format(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 2, includeCode: true)
    }

    public var statusText: String {
        switch state {
        case .notConfigured:
            return "Not configured"
        case .loading:
            return "Refreshing"
        case .loaded(let snapshot):
            return snapshot.isAvailable ? "Available" : "Balance insufficient"
        case .failed(let message, _):
            return message
        }
    }

    public var lastRefreshText: String {
        guard let fetchedAt = state.lastSnapshot?.fetchedAt else {
            return "Never refreshed"
        }
        return "Last refreshed \(Self.relativeFormatter.localizedString(for: fetchedAt, relativeTo: Date()))"
    }

    public var keyStatusText: String {
        isEditingKey ? "Enter API key" : "API key configured"
    }

    public func onAppear() {
        controller.startAutoRefresh()
        Task {
            await refresh()
        }
    }

    public func refresh() async {
        await controller.refresh()
        state = controller.state
    }

    public func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .failed(message: "API key cannot be empty.", last: state.lastSnapshot)
            return
        }
        do {
            try controller.saveCredential(trimmed)
            apiKeyInput = ""
            isEditingKey = false
            Task { await refresh() }
        } catch {
            state = .failed(message: "Could not save API key to Keychain.", last: state.lastSnapshot)
        }
    }

    public func replaceAPIKey() {
        apiKeyInput = ""
        isEditingKey = true
    }

    public func deleteAPIKey() {
        do {
            try controller.deleteCredential()
            apiKeyInput = ""
            isEditingKey = true
            state = controller.state
        } catch {
            state = .failed(message: "Could not delete API key from Keychain.", last: state.lastSnapshot)
        }
    }

    public func markKeyConfiguredForTesting() {
        apiKeyInput = ""
        isEditingKey = false
    }

    private func format(_ value: Decimal, currency: String, fractionDigits: Int, includeCode: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.currencySymbol = currency == "CNY" ? "¥" : currency
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let formatted = formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        return includeCode ? "\(formatted) \(currency)" : formatted
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

private final class PreviewHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(data: Data(), statusCode: 500)
    }
}
```

- [ ] **Step 6: Run refresh and view model tests**

Run:

```bash
swift test --filter BalanceRefreshControllerTests
swift test --filter MenuBarBalanceViewModelTests
```

Expected: PASS.

- [ ] **Step 7: Commit refresh and view model**

```bash
git add Sources/APIInquiryCore/Refresh Sources/APIInquiryCore/ViewModels Tests/APIInquiryCoreTests/BalanceRefreshControllerTests.swift Tests/APIInquiryCoreTests/MenuBarBalanceViewModelTests.swift
git commit -m "feat: coordinate balance refresh state"
```

---

### Task 5: Native Menu Bar UI And Local App Bundle

**Files:**
- Modify: `Package.swift`
- Create: `Sources/APIInquiryApp/APIInquiryApp.swift`
- Create: `Sources/APIInquiryApp/MenuBarContentView.swift`
- Create: `Scripts/build-local-app.sh`

- [ ] **Step 1: Add the app executable target to `Package.swift`**

Replace `Package.swift` with:

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
            name: "APIInquiryApp",
            targets: ["APIInquiryApp"]
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .executableTarget(
            name: "APIInquiryApp",
            dependencies: ["APIInquiryCore"]
        ),
        .testTarget(
            name: "APIInquiryCoreTests",
            dependencies: ["APIInquiryCore"]
        )
    ]
)
```

- [ ] **Step 2: Create SwiftUI app entry point**

Create `Sources/APIInquiryApp/APIInquiryApp.swift`:

```swift
import APIInquiryCore
import AppKit
import SwiftUI

@main
struct APIInquiryApp: App {
    @StateObject private var viewModel = MenuBarBalanceViewModel.production()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            MenuBarContentView(viewModel: viewModel)
                .onAppear {
                    viewModel.onAppear()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Create minimal expanded panel**

Create `Sources/APIInquiryApp/MenuBarContentView.swift`:

```swift
import APIInquiryCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarBalanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            balanceBlock
            statusBlock
            Divider()
            keyBlock
            actionBlock
        }
        .padding(16)
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Text("DeepSeek")
                .font(.headline)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh balance")
        }
    }

    private var balanceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.panelBalanceText)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusBlock: some View {
        Text(viewModel.lastRefreshText)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var keyBlock: some View {
        if viewModel.isEditingKey || viewModel.statusText == "Not configured" {
            VStack(alignment: .leading, spacing: 8) {
                SecureField("DeepSeek API Key", text: $viewModel.apiKeyInput)
                HStack {
                    Button("Save") {
                        viewModel.saveAPIKey()
                    }
                    Button("Cancel") {
                        viewModel.apiKeyInput = ""
                        viewModel.isEditingKey = false
                    }
                    .disabled(viewModel.statusText == "Not configured")
                }
            }
        } else {
            HStack {
                Text(viewModel.keyStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Replace") {
                    viewModel.replaceAPIKey()
                }
                Button("Delete") {
                    viewModel.deleteAPIKey()
                }
            }
        }
    }

    private var actionBlock: some View {
        HStack {
            Button("Open Console") {
                if let url = URL(string: "https://platform.deepseek.com/usage") {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 4: Create local app bundle script**

Create `Scripts/build-local-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/APIInquiry.app"
EXECUTABLE_SOURCE="$ROOT_DIR/.build/debug/APIInquiryApp"
EXECUTABLE_DEST="$APP_DIR/Contents/MacOS/APIInquiry"

cd "$ROOT_DIR"
swift build

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE_SOURCE" "$EXECUTABLE_DEST"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>APIInquiry</string>
  <key>CFBundleIdentifier</key>
  <string>com.api-inquiry.menu-bar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>API Inquiry</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
```

- [ ] **Step 5: Make the script executable**

Run:

```bash
chmod +x Scripts/build-local-app.sh
```

Expected: command exits successfully.

- [ ] **Step 6: Build the executable**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 7: Build the local `.app` bundle**

Run:

```bash
Scripts/build-local-app.sh
```

Expected: output includes `Built /Users/zbw/Desktop/API-inquiry/.build/APIInquiry.app`.

- [ ] **Step 8: Commit app UI and bundle script**

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

Create `README.md`:

````markdown
# API Inquiry

API Inquiry is a native macOS menu bar app for checking DeepSeek API account balance.

## Requirements

- macOS 13 Ventura or later
- Xcode command line tools
- A DeepSeek API key

## Run Tests

```bash
swift test
```

## Build Local App

```bash
Scripts/build-local-app.sh
```

The app bundle is created at `.build/APIInquiry.app`.

## Security

The DeepSeek API key is stored in macOS Keychain. The app does not show the key after saving.
````

- [ ] **Step 2: Create Chinese README**

Create `README_zh.md`:

````markdown
# API Inquiry

API Inquiry 是一个原生 macOS 菜单栏应用，用于查询 DeepSeek API 账号余额。

## 运行要求

- macOS 13 Ventura 或更高版本
- Xcode 命令行工具
- DeepSeek API Key

## 运行测试

```bash
swift test
```

## 构建本地 App

```bash
Scripts/build-local-app.sh
```

应用包会生成在 `.build/APIInquiry.app`。

## 安全

DeepSeek API Key 存储在 macOS Keychain 中。保存后，应用不会再显示密钥明文。
````

- [ ] **Step 3: Run all automated tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Build the app bundle**

Run:

```bash
Scripts/build-local-app.sh
```

Expected: output includes `Built /Users/zbw/Desktop/API-inquiry/.build/APIInquiry.app`.

- [ ] **Step 5: Launch for manual testing**

Run:

```bash
open .build/APIInquiry.app
```

Expected: macOS launches the menu bar app. If the sandbox requires approval for `open`, request escalation for this command and explain that it launches the local app for manual UI verification.

- [ ] **Step 6: Complete manual checks**

Perform these checks:

- Launch with no API key and confirm the menu bar title is `DS --`.
- Open the menu and confirm the panel asks for a DeepSeek API key.
- Save a real DeepSeek API key locally.
- Confirm the menu bar title changes to `DS ¥<balance with one decimal>`.
- Confirm the panel shows `¥<balance with two decimals> CNY`.
- Click refresh and confirm the app stays responsive.
- Replace the API key and confirm the old key is not displayed.
- Delete the API key and confirm setup state returns.
- Click Open Console and confirm `https://platform.deepseek.com/usage` opens.
- Quit the app from the panel.

- [ ] **Step 7: Commit README and verification docs**

```bash
git add README.md README_zh.md
git commit -m "docs: add local run instructions"
```

- [ ] **Step 8: Final verification before handoff**

Run:

```bash
git status --short
swift test
Scripts/build-local-app.sh
```

Expected:

- `git status --short` prints no tracked source changes.
- `swift test` passes.
- `Scripts/build-local-app.sh` builds `.build/APIInquiry.app`.

---

## Plan Self-Review

- Spec coverage: balance-only DeepSeek menu bar app, 5-minute refresh, manual refresh, Keychain storage, minimal panel, provider abstraction, no first-release charts, and local source deliverable are all covered.
- Placeholder scan: the plan uses exact files, code blocks, commands, expected results, and commit messages.
- Type consistency: `ProviderID`, `BalanceSnapshot`, `BalanceState`, `BalanceProvider`, `HTTPClient`, `CredentialStore`, `BalanceRefreshController`, and `MenuBarBalanceViewModel` names are consistent across tasks.
