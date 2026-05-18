import APIInquiryCore
import Foundation

enum UsageConsoleViewModelTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testProviderSummariesExposeUnconfiguredProvider(using: harness)
        await testProviderSummariesExposeConfiguredActiveProvider(using: harness)
        await testProviderSummariesExposeInvalidProvider(using: harness)
        await testSavingAPIKeyRefreshesBalance(using: harness)
        await testSaveFailureKeepsInputAndDoesNotExposeKey(using: harness)
        await testConfirmingAPIKeyDeletionReturnsBalanceToSetup(using: harness)
    }

    @MainActor
    private static func testProviderSummariesExposeUnconfiguredProvider(using harness: TestHarness) {
        let viewModel = makeViewModel()

        harness.expectEqual(viewModel.providerSummaries.count, 1, "console provider summary count")
        harness.expectEqual(viewModel.providerSummaries.first?.displayName, "DeepSeek", "console provider summary name")
        harness.expectEqual(
            viewModel.providerSummaries.first?.homepageURL,
            URL(string: "https://platform.deepseek.com/usage")!,
            "console provider homepage url"
        )
        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Not configured", "console provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Not configured", "console provider validation status")
        harness.expectEqual(viewModel.providerSummaries.first?.balanceText, "--", "console provider balance placeholder")
    }

    @MainActor
    private static func testProviderSummariesExposeConfiguredActiveProvider(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Configured", "console configured provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Active", "console active provider validation status")
        harness.expectEqual(viewModel.providerSummaries.first?.balanceText, "¥68.65 CNY", "console provider balance")
    }

    @MainActor
    private static func testProviderSummariesExposeInvalidProvider(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let credentialStore = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        await controller.refresh()

        harness.expectEqual(viewModel.providerSummaries.first?.apiKeyStatusText, "Configured", "console invalid provider key status")
        harness.expectEqual(viewModel.providerSummaries.first?.validationStatusText, "Invalid", "console invalid provider validation status")
    }

    @MainActor
    private static func testSavingAPIKeyRefreshesBalance(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(.balance(snapshot))])
        let credentialStore = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
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
            controller: controller
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
        let provider = MockBalanceProvider(results: [.success(.balance(makeSnapshot(total: "68.65")))])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
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
        credentialStore: CredentialStore = InMemoryCredentialStore()
    ) -> UsageConsoleViewModel {
        let provider = MockBalanceProvider(results: [])
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        return UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )
    }
}
