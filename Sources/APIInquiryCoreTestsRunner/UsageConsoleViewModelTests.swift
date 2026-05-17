import APIInquiryCore
import Foundation

enum UsageConsoleViewModelTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testImportingCSVExposesSummariesAndPersistsDataset(using: harness)
        testClearingUsageDataDoesNotDeleteAPIKey(using: harness)
        await testSavingAPIKeyRefreshesBalance(using: harness)
        await testSaveFailureKeepsInputAndDoesNotExposeKey(using: harness)
        await testConfirmingAPIKeyDeletionReturnsBalanceToSetup(using: harness)
    }

    @MainActor
    private static func testImportingCSVExposesSummariesAndPersistsDataset(using harness: TestHarness) {
        let usageStore = InMemoryUsageDataStore()
        let viewModel = makeViewModel(usageStore: usageStore)
        let csv = """
        Date,Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        2024-05-01,deepseek-chat,2,100,40,140,1.25,CNY
        2024-05-02,deepseek-reasoner,3,200,60,260,2.75,CNY
        """

        viewModel.importUsageCSV(csv, sourceFileName: "usage.csv", importedAt: Date(timeIntervalSince1970: 1_716_000_000))

        harness.expectEqual(viewModel.usageDataset?.records.count, 2, "console imported records")
        harness.expectEqual(viewModel.usageTotals?.cost, decimal("4.00"), "console usage total cost")
        harness.expectEqual(viewModel.modelSummaries.count, 2, "console model summaries count")
        harness.expectEqual(viewModel.detailRecords.first?.model, "deepseek-reasoner", "console details newest first")
        harness.expectEqual(try? usageStore.loadDataset()?.records.count, 2, "console import persisted dataset")
        harness.expectEqual(viewModel.usageFeedback, SettingsFeedback(kind: .success, message: "Imported 2 usage records."), "console import feedback")
    }

    @MainActor
    private static func testClearingUsageDataDoesNotDeleteAPIKey(using harness: TestHarness) {
        let usageStore = InMemoryUsageDataStore(dataset: makeDataset())
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(credentialStore: credentialStore, usageStore: usageStore)

        viewModel.loadUsageData()
        viewModel.clearUsageData()

        harness.expectEqual(viewModel.usageDataset, nil, "console clears usage dataset")
        harness.expectEqual(try? usageStore.loadDataset(), nil, "console clears usage store")
        harness.expectEqual(try? credentialStore.credential(forAccount: "deepseek-api-key"), "test-key", "console clear keeps api key")
    }

    @MainActor
    private static func testSavingAPIKeyRefreshesBalance(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(snapshot)])
        let credentialStore = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            usageDataStore: InMemoryUsageDataStore()
        )
        viewModel.apiKeyInput = "test-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "", "console api key input clears")
        harness.expectEqual(try? credentialStore.credential(forAccount: "deepseek-api-key"), "test-key", "console api key saved")
        harness.expectEqual(provider.lastAPIKey, "test-key", "console save refreshes balance")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "console credential configured")
        harness.expectEqual(viewModel.settingsFeedback, SettingsFeedback(kind: .success, message: "Saved securely."), "console save feedback")
    }

    @MainActor
    private static func testSaveFailureKeepsInputAndDoesNotExposeKey(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let credentialStore = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            usageDataStore: InMemoryUsageDataStore()
        )
        viewModel.apiKeyInput = "bad-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "bad-key", "console save failure keeps input")
        harness.expectEqual(viewModel.settingsFeedback?.kind, .warning, "console save failure warning")
        harness.expectTrue(
            viewModel.settingsFeedback?.message.contains("bad-key") == false,
            "console save failure does not expose key"
        )
    }

    @MainActor
    private static func testConfirmingAPIKeyDeletionReturnsBalanceToSetup(using harness: TestHarness) async {
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let provider = MockBalanceProvider(results: [.success(makeSnapshot(total: "68.65"))])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            usageDataStore: InMemoryUsageDataStore()
        )

        await controller.refresh()
        viewModel.requestAPIKeyDeletion()
        await viewModel.confirmAPIKeyDeletion()

        harness.expectEqual(try? credentialStore.credential(forAccount: "deepseek-api-key"), nil, "console delete removes key")
        harness.expectEqual(viewModel.credentialStatusText, "Not configured", "console delete updates credential status")
        harness.expectEqual(controller.state, .notConfigured, "console delete marks balance not configured")
    }

    @MainActor
    private static func makeViewModel(
        credentialStore: CredentialStore = InMemoryCredentialStore(),
        usageStore: UsageDataStore = InMemoryUsageDataStore()
    ) -> UsageConsoleViewModel {
        let provider = MockBalanceProvider(results: [])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        return UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            usageDataStore: usageStore
        )
    }

    private static func makeDataset() -> UsageDataset {
        UsageDataset(
            records: [
                UsageRecord(
                    occurredAt: Date(timeIntervalSince1970: 1_716_000_000),
                    model: "deepseek-chat",
                    requestCount: 1,
                    inputTokens: 10,
                    outputTokens: 4,
                    totalTokens: 14,
                    cost: decimal("0.50"),
                    currency: "CNY"
                )
            ],
            metadata: UsageImportMetadata(
                sourceFileName: "usage.csv",
                importedAt: Date(timeIntervalSince1970: 1_716_100_000),
                parserVersion: 1
            )
        )
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
