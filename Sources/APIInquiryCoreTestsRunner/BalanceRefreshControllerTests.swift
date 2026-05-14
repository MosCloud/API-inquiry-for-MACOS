import APIInquiryCore
import Foundation

enum BalanceRefreshControllerTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        await testMissingCredentialSetsNotConfigured(using: harness)
        await testSuccessfulRefreshLoadsSnapshot(using: harness)
        await testFailurePreservesLastSnapshot(using: harness)
        await testOverlappingRefreshDoesNotStartSecondProviderCall(using: harness)
        await testCancellationRestoresPreviousState(using: harness)
        await testCancelledURLErrorRestoresPreviousState(using: harness)
        testDefaultRefreshIntervalIsFiveMinutes(using: harness)
    }

    @MainActor
    private static func testMissingCredentialSetsNotConfigured(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.success(makeSnapshot(total: "68.65"))])
        let controller = BalanceRefreshController(
            provider: provider,
            credentialStore: InMemoryCredentialStore()
        )

        await controller.refresh()

        harness.expectEqual(controller.state, .notConfigured, "missing credential state")
        harness.expectEqual(provider.fetchCount, 0, "missing credential does not call provider")
    }

    @MainActor
    private static func testSuccessfulRefreshLoadsSnapshot(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.success(makeSnapshot(total: "68.65"))])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(makeSnapshot(total: "68.65")), "successful refresh state")
        harness.expectEqual(provider.lastAPIKey, "test-key", "successful refresh api key")
    }

    @MainActor
    private static func testFailurePreservesLastSnapshot(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(snapshot),
            .failure(BalanceProviderError.rateLimited)
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state.lastSnapshot, snapshot, "failed refresh last snapshot")
        harness.expectEqual(
            controller.state,
            .failed(message: "Balance API rate limit reached. Try again shortly.", last: snapshot),
            "failed refresh state"
        )
    }

    @MainActor
    private static func testOverlappingRefreshDoesNotStartSecondProviderCall(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let probe = SuspendedRefreshProbe()
        let provider = SuspendedBalanceProvider(probe: probe)
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        let firstRefresh = Task { await controller.refresh() }
        await waitForFetchCount(1, probe: probe)

        let secondRefresh = Task { await controller.refresh() }
        await Task.yield()

        harness.expectEqual(await probe.fetchCount(), 1, "overlapping refresh fetch count")

        await probe.complete(with: snapshot)
        await firstRefresh.value
        await secondRefresh.value

        harness.expectEqual(controller.state, .loaded(snapshot), "overlapping refresh final state")
    }

    @MainActor
    private static func testCancellationRestoresPreviousState(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(snapshot),
            .failure(CancellationError())
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(snapshot), "cancellation restores previous state")
    }

    @MainActor
    private static func testCancelledURLErrorRestoresPreviousState(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(snapshot),
            .failure(URLError(.cancelled))
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(snapshot), "cancelled URL error restores previous state")
    }

    @MainActor
    private static func testDefaultRefreshIntervalIsFiveMinutes(using harness: TestHarness) {
        let provider = MockBalanceProvider(results: [])
        let controller = BalanceRefreshController(provider: provider, credentialStore: InMemoryCredentialStore())

        harness.expectEqual(controller.refreshInterval, 300, "default refresh interval")
    }
}

private final class SuspendedBalanceProvider: BalanceProvider {
    let id: ProviderID = .deepseek
    let displayName = "DeepSeek"
    let menuPrefix = "DS"
    let credentialAccount = "deepseek-api-key"

    private let probe: SuspendedRefreshProbe

    init(probe: SuspendedRefreshProbe) {
        self.probe = probe
    }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        try await probe.suspendAndRecordFetch()
    }
}

private actor SuspendedRefreshProbe {
    private var count = 0
    private var continuation: CheckedContinuation<BalanceSnapshot, Error>?

    func suspendAndRecordFetch() async throws -> BalanceSnapshot {
        count += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func fetchCount() -> Int {
        count
    }

    func complete(with snapshot: BalanceSnapshot) {
        continuation?.resume(returning: snapshot)
        continuation = nil
    }
}

private func waitForFetchCount(_ expected: Int, probe: SuspendedRefreshProbe) async {
    for _ in 0..<20 {
        if await probe.fetchCount() == expected {
            return
        }
        await Task.yield()
    }
}

final class MockBalanceProvider: BalanceProvider {
    let id: ProviderID = .deepseek
    let displayName = "DeepSeek"
    let menuPrefix = "DS"
    let credentialAccount = "deepseek-api-key"

    private var results: [Result<BalanceSnapshot, Error>]
    private(set) var fetchCount = 0
    private(set) var lastAPIKey: String?

    init(results: [Result<BalanceSnapshot, Error>]) {
        self.results = results
    }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        fetchCount += 1
        lastAPIKey = apiKey

        guard !results.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }
        return try results.removeFirst().get()
    }
}

func makeSnapshot(
    total: String,
    currency: String = "CNY",
    isAvailable: Bool = true,
    fetchedAt: Date = Date(timeIntervalSince1970: 1_715_000_000)
) -> BalanceSnapshot {
    BalanceSnapshot(
        providerID: .deepseek,
        totalBalance: Decimal(string: total, locale: Locale(identifier: "en_US_POSIX"))!,
        currency: currency,
        isAvailable: isAvailable,
        grantedBalance: nil,
        toppedUpBalance: nil,
        fetchedAt: fetchedAt
    )
}
