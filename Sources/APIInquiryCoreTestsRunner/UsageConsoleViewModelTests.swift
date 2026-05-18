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
        await testMultiProviderSummariesExposePrimaryAndPlanUsage(using: harness)
        testAddingProviderUpdatesAvailableProviderOptions(using: harness)
        testRemovingProviderShowsFeedbackWhenCredentialDeletionFails(using: harness)
        testRemovingProviderClearsProviderScopedAPIKeyInput(using: harness)
        await testSavingProviderScopedAPIKeyRefreshesOnlyThatProvider(using: harness)
    }

    @MainActor
    private static func testMultiProviderSummariesExposePrimaryAndPlanUsage(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .zhipuCodingPlan)
        await coordinator.refreshAddedProviders()
        let viewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "zhipu-coding-plan-api-key": "zhipu-key"
            ])
        )

        harness.expectEqual(viewModel.providerSummaries.count, 2, "multi console provider summary count")
        harness.expectEqual(viewModel.providerSummaries.first?.id, .deepseek, "multi console first provider id")
        harness.expectEqual(viewModel.providerSummaries.last?.id, .zhipuCodingPlan, "multi console zhipu provider id")
        harness.expectEqual(viewModel.providerSummaries.last?.balanceText, "5h 17%", "multi console zhipu usage text")
        harness.expectEqual(viewModel.providerSummaries.last?.validationStatusText, "Plan available", "multi console zhipu status")
        harness.expectTrue(viewModel.providerSummaries.last?.isPrimary == true, "multi console zhipu primary")
    }

    @MainActor
    private static func testAddingProviderUpdatesAvailableProviderOptions(using harness: TestHarness) {
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek],
            primaryProviderID: .deepseek
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: InMemoryCredentialStore())

        harness.expectEqual(viewModel.availableProviderIDsToAdd, [.zhipuCodingPlan], "console available provider before add")

        viewModel.addProvider(.zhipuCodingPlan)

        harness.expectEqual(viewModel.availableProviderIDsToAdd, [], "console available provider after add")
        harness.expectEqual(viewModel.providerSummaries.map(\.id), [.deepseek, .zhipuCodingPlan], "console summaries after add")
    }

    @MainActor
    private static func testRemovingProviderShowsFeedbackWhenCredentialDeletionFails(using harness: TestHarness) {
        let store = FailingDeleteCredentialStore(credentialsByAccount: ["zhipu-coding-plan-api-key": "test-key"])
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek, .zhipuCodingPlan],
            primaryProviderID: .deepseek,
            credentialStore: store
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: store)

        viewModel.removeProvider(.zhipuCodingPlan)

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek, .zhipuCodingPlan], "console keeps provider when remove key delete fails")
        harness.expectEqual(viewModel.settingsFeedback(for: .zhipuCodingPlan)?.kind, .error, "console remove failure feedback kind")
        harness.expectTrue(
            viewModel.settingsFeedback(for: .zhipuCodingPlan)?.message.isEmpty == false,
            "console remove failure feedback message"
        )
    }

    @MainActor
    private static func testRemovingProviderClearsProviderScopedAPIKeyInput(using harness: TestHarness) {
        let coordinator = makeMultiProviderCoordinator(
            addedProviderIDs: [.deepseek, .zhipuCodingPlan],
            primaryProviderID: .deepseek
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: InMemoryCredentialStore())
        viewModel.setAPIKeyInput("typed-zhipu-key", for: .zhipuCodingPlan)

        viewModel.removeProvider(.zhipuCodingPlan)
        viewModel.addProvider(.zhipuCodingPlan)

        harness.expectEqual(viewModel.apiKeyInput(for: .zhipuCodingPlan), "", "console remove clears provider-scoped api key input")
    }

    @MainActor
    private static func testSavingProviderScopedAPIKeyRefreshesOnlyThatProvider(using harness: TestHarness) async {
        let deepSeek = MockBalanceProvider(
            id: .deepseek,
            displayName: "DeepSeek",
            menuPrefix: "DS",
            credentialAccount: "deepseek-api-key",
            homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
            results: [.success(.balance(makeSnapshot(providerID: .deepseek, total: "68.65")))]
        )
        let zhipu = MockBalanceProvider(
            id: .zhipuCodingPlan,
            displayName: "Zhipu GLM Coding Plan",
            menuPrefix: "GLM",
            credentialAccount: "zhipu-coding-plan-api-key",
            homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
            results: [.success(.planUsage(PlanUsageSnapshot(
                providerID: .zhipuCodingPlan,
                windowLabel: "5h",
                usagePercentage: Decimal(17),
                resetAt: nil,
                isAvailable: true,
                fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
            )))]
        )
        let store = InMemoryCredentialStore()
        let coordinator = MultiProviderBalanceCoordinator(
            providers: [deepSeek, zhipu],
            credentialStore: store,
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [.deepseek, .zhipuCodingPlan])
        )
        let viewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: store)
        viewModel.setAPIKeyInput("zhipu-key", for: .zhipuCodingPlan)

        await viewModel.saveAPIKey(for: .zhipuCodingPlan)

        harness.expectEqual(try? store.credential(forAccount: "zhipu-coding-plan-api-key"), "zhipu-key", "console provider-scoped key saved")
        harness.expectEqual(zhipu.lastAPIKey, "zhipu-key", "console provider-scoped save refreshes zhipu")
        harness.expectEqual(deepSeek.fetchCount, 0, "console provider-scoped save does not refresh deepseek")
        harness.expectEqual(viewModel.apiKeyInput(for: .zhipuCodingPlan), "", "console provider-scoped input clears")
        harness.expectEqual(viewModel.settingsFeedback(for: .zhipuCodingPlan), SettingsFeedback(kind: .success, message: "Saved securely."), "console provider-scoped save feedback")
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
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .neutral, "console unconfigured provider status tone")
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
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .success, "console active provider status tone")
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
        harness.expectEqual(viewModel.providerSummaries.first?.statusTone, .warning, "console invalid provider status tone")
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

    @MainActor
    private static func makeMultiProviderCoordinator(
        addedProviderIDs: [ProviderID] = [.deepseek, .zhipuCodingPlan],
        primaryProviderID: ProviderID,
        credentialStore: CredentialStore = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "deepseek-key",
            "zhipu-coding-plan-api-key": "zhipu-key"
        ])
    ) -> MultiProviderBalanceCoordinator {
        let deepSeekSnapshot = makeSnapshot(providerID: .deepseek, total: "68.65")
        let zhipuSnapshot = PlanUsageSnapshot(
            providerID: .zhipuCodingPlan,
            windowLabel: "5h",
            usagePercentage: Decimal(17),
            resetAt: nil,
            isAvailable: true,
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        return MultiProviderBalanceCoordinator(
            providers: [
                MockBalanceProvider(
                    id: .deepseek,
                    displayName: "DeepSeek",
                    menuPrefix: "DS",
                    credentialAccount: "deepseek-api-key",
                    homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
                    results: [.success(.balance(deepSeekSnapshot))]
                ),
                MockBalanceProvider(
                    id: .zhipuCodingPlan,
                    displayName: "Zhipu GLM Coding Plan",
                    menuPrefix: "GLM",
                    credentialAccount: "zhipu-coding-plan-api-key",
                    homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
                    results: [.success(.planUsage(zhipuSnapshot))]
                )
            ],
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: addedProviderIDs,
                primaryProviderID: primaryProviderID
            )
        )
    }
}

private final class FailingDeleteCredentialStore: CredentialStore {
    private var credentialsByAccount: [String: String]

    init(credentialsByAccount: [String: String]) {
        self.credentialsByAccount = credentialsByAccount
    }

    func credential(forAccount account: String) throws -> String? {
        credentialsByAccount[account]
    }

    func saveCredential(_ credential: String, forAccount account: String) throws {
        credentialsByAccount[account] = credential
    }

    func deleteCredential(forAccount account: String) throws {
        throw CredentialStoreError.unexpectedStatus(-1)
    }
}
