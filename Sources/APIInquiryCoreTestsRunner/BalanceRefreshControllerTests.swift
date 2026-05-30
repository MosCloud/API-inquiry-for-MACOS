import APIInquiryCore
import Foundation

enum BalanceRefreshControllerTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        await testMissingCredentialSetsNotConfigured(using: harness)
        await testSuccessfulRefreshLoadsSnapshot(using: harness)
        await testRefreshUsesInjectedCredentialAccount(using: harness)
        await testFailurePreservesLastSnapshot(using: harness)
        await testAuthenticationFailureUsesTypedFailureKind(using: harness)
        await testAuthenticationFailureCanUseChineseMessage(using: harness)
        await testOverlappingRefreshDoesNotStartSecondProviderCall(using: harness)
        await testMarkNotConfiguredInvalidatesInFlightRefresh(using: harness)
        await testCancellationRestoresPreviousState(using: harness)
        await testCancelledURLErrorRestoresPreviousState(using: harness)
        testDefaultRefreshIntervalIsFiveMinutes(using: harness)
    }

    @MainActor
    private static func testMissingCredentialSetsNotConfigured(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
        let controller = makeTestRefreshController(
            provider: provider,
            credentialStore: InMemoryCredentialStore()
        )

        await controller.refresh()

        harness.expectEqual(controller.state, .notConfigured, "missing credential state")
        harness.expectEqual(provider.fetchCount, 0, "missing credential does not call provider")
    }

    @MainActor
    private static func testSuccessfulRefreshLoadsSnapshot(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(.balance(makeSnapshot(total: "68.65"))), "successful refresh state")
        harness.expectEqual(provider.lastAPIKey, "test-key", "successful refresh api key")
    }

    @MainActor
    private static func testRefreshUsesInjectedCredentialAccount(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
        let store = InMemoryCredentialStore(credentialsByAccount: ["custom-account": "custom-key"])
        let controller = makeTestRefreshController(
            provider: provider,
            credentialStore: store,
            credentialAccount: "custom-account"
        )

        await controller.refresh()

        harness.expectEqual(provider.lastAPIKey, "custom-key", "refresh uses injected credential account")
    }

    @MainActor
    private static func testFailurePreservesLastSnapshot(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(.balance(snapshot)),
            .failure(BalanceProviderError.rateLimited)
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state.lastSnapshot, .balance(snapshot), "failed refresh last snapshot")
        harness.expectEqual(
            controller.state,
            BalanceState.failed(
                message: "Balance API rate limit reached. Try again shortly.",
                kind: .rateLimited,
                last: .balance(snapshot)
            ),
            "failed refresh state"
        )
    }

    @MainActor
    private static func testAuthenticationFailureUsesTypedFailureKind(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()

        harness.expectEqual(
            controller.state,
            .failed(
                message: "API key may be invalid. Replace or delete it in the console.",
                kind: .authenticationFailed,
                last: nil
            ),
            "authentication failure kind"
        )
    }

    @MainActor
    private static func testAuthenticationFailureCanUseChineseMessage(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        let controller = makeTestRefreshController(
            provider: provider,
            credentialStore: store,
            localizedStrings: { LocalizedStrings(language: .zh) }
        )

        await controller.refresh()

        harness.expectEqual(
            controller.state,
            .failed(
                message: "API 密钥可能无效，请在控制台中更换或删除。",
                kind: .authenticationFailed,
                last: nil
            ),
            "authentication failure chinese message"
        )
    }

    @MainActor
    private static func testOverlappingRefreshDoesNotStartSecondProviderCall(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let probe = SuspendedRefreshProbe()
        let provider = SuspendedBalanceProvider(probe: probe)
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        let firstRefresh = Task { await controller.refresh() }
        await waitForFetchCount(1, probe: probe)

        let secondRefresh = Task { await controller.refresh() }
        await Task.yield()

        harness.expectEqual(await probe.fetchCount(), 1, "overlapping refresh fetch count")

        await probe.complete(with: snapshot)
        await firstRefresh.value
        await secondRefresh.value

        harness.expectEqual(controller.state, .loaded(.balance(snapshot)), "overlapping refresh final state")
    }

    @MainActor
    private static func testMarkNotConfiguredInvalidatesInFlightRefresh(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let probe = SuspendedRefreshProbe()
        let provider = SuspendedBalanceProvider(probe: probe)
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        let refresh = Task { await controller.refresh() }
        await waitForFetchCount(1, probe: probe)

        controller.markNotConfigured()
        await probe.complete(with: snapshot)
        await refresh.value

        harness.expectEqual(controller.state, .notConfigured, "mark not configured invalidates in-flight refresh")
    }

    @MainActor
    private static func testCancellationRestoresPreviousState(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(.balance(snapshot)),
            .failure(CancellationError())
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(.balance(snapshot)), "cancellation restores previous state")
    }

    @MainActor
    private static func testCancelledURLErrorRestoresPreviousState(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [
            .success(.balance(snapshot)),
            .failure(URLError(.cancelled))
        ])
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = makeTestRefreshController(provider: provider, credentialStore: store)

        await controller.refresh()
        await controller.refresh()

        harness.expectEqual(controller.state, .loaded(.balance(snapshot)), "cancelled URL error restores previous state")
    }

    @MainActor
    private static func testDefaultRefreshIntervalIsFiveMinutes(using harness: TestHarness) {
        let provider = MockBalanceProvider(results: [])
        let controller = makeTestRefreshController(provider: provider, credentialStore: InMemoryCredentialStore())

        harness.expectEqual(controller.refreshInterval, 300, "default refresh interval")
    }
}

private final class SuspendedBalanceProvider: BalanceProvider {
    let id: ProviderID = .deepseek

    private let probe: SuspendedRefreshProbe

    init(probe: SuspendedRefreshProbe) {
        self.probe = probe
    }

    func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        .balance(try await probe.suspendAndRecordFetch())
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
    let id: ProviderID

    private var results: [Result<ProviderSnapshot, Error>]
    private(set) var fetchCount = 0
    private(set) var lastAPIKey: String?

    init(
        id: ProviderID = .deepseek,
        results: [Result<ProviderSnapshot, Error>]
    ) {
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

func makeSnapshot(
    providerID: ProviderID = .deepseek,
    total: String,
    currency: String = "CNY",
    isAvailable: Bool = true,
    fetchedAt: Date = Date(timeIntervalSince1970: 1_715_000_000)
) -> BalanceSnapshot {
    BalanceSnapshot(
        providerID: providerID,
        totalBalance: Decimal(string: total, locale: Locale(identifier: "en_US_POSIX"))!,
        currency: currency,
        isAvailable: isAvailable,
        grantedBalance: nil,
        toppedUpBalance: nil,
        fetchedAt: fetchedAt
    )
}
