import APIInquiryCore
import Foundation

/// A provider that stays suspended until the test releases it, so a refresh is
/// guaranteed to be in flight while the key is saved.
final class BlockingSnapshotProvider: BalanceProvider {
    let id: ProviderID

    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var permits = 0
    private(set) var requestedKeys: [String] = []

    init(id: ProviderID) {
        self.id = id
    }

    var startedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requestedKeys.count
    }

    func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        lock.lock()
        requestedKeys.append(apiKey)
        if permits > 0 {
            permits -= 1
            lock.unlock()
            return snapshot()
        }
        lock.unlock()

        await withCheckedContinuation { continuation in
            lock.lock()
            if permits > 0 {
                permits -= 1
                lock.unlock()
                continuation.resume()
            } else {
                continuations.append(continuation)
                lock.unlock()
            }
        }

        return snapshot()
    }

    /// Allows `count` suspended or future fetches to finish.
    func release(_ count: Int) {
        lock.lock()
        var resumable: [CheckedContinuation<Void, Never>] = []
        for _ in 0..<count {
            if continuations.isEmpty {
                permits += 1
            } else {
                resumable.append(continuations.removeFirst())
            }
        }
        lock.unlock()
        resumable.forEach { $0.resume() }
    }

    private func snapshot() -> ProviderSnapshot {
        .balance(BalanceSnapshot(
            providerID: id,
            totalBalance: Decimal(string: "10")!,
            currency: "CNY",
            isAvailable: true,
            grantedBalance: nil,
            toppedUpBalance: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        ))
    }
}

@MainActor
final class CompletionFlag {
    var value = false
}

enum SaveDuringRefreshTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        await testSavingDuringRefreshStillReportsAndRefetches(using: harness)
    }

    @MainActor
    private static func testSavingDuringRefreshStillReportsAndRefetches(using harness: TestHarness) async {
        let provider = BlockingSnapshotProvider(id: .deepseek)
        let registration = testRegistration(descriptor: testDescriptor(for: .deepseek), provider: { provider })
        let credentialStore = InMemoryCredentialStore(
            credentialsByAccount: [testCredentialAccount(for: .deepseek): "old-key"]
        )
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: [registration],
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek],
                primaryProviderID: .deepseek
            ),
            defaultProviderID: .deepseek
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: credentialStore)

        let finished = CompletionFlag()
        let refreshTask = Task {
            await coordinator.refresh(.deepseek)
            finished.value = true
        }
        await waitUntil { provider.startedCount == 1 }
        harness.expectEqual(provider.requestedKeys, ["old-key"], "first refresh reads the old key")

        viewModel.setAPIKeyInput("new-key", for: .deepseek)
        await viewModel.saveAPIKey(for: .deepseek)

        harness.expectTrue(
            viewModel.settingsFeedback(for: .deepseek) != nil,
            "saving during an in-flight refresh reports a result"
        )

        provider.release(1)
        await waitUntil { provider.startedCount >= 2 }
        harness.expectEqual(provider.requestedKeys.last, "new-key", "the follow-up refresh uses the new key")

        provider.release(1)
        let completed = await waitUntil { finished.value }
        harness.expectTrue(completed, "the refresh finishes after both requests are released")
        if completed {
            await refreshTask.value
        } else {
            refreshTask.cancel()
        }

        let storedKey = try? credentialStore.credential(forAccount: testCredentialAccount(for: .deepseek))
        harness.expectEqual(storedKey, "new-key", "the new key is stored")
    }

    @MainActor
    @discardableResult
    private static func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return false
    }
}
