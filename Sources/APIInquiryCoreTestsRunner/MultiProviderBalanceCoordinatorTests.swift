import APIInquiryCore
import Foundation

enum MultiProviderBalanceCoordinatorTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testDefaultsToDeepSeekProvider(using: harness)
        testAddSetPrimaryAndRemoveProvider(using: harness)
        testRemovingProviderCanDeleteCredential(using: harness)
        await testRefreshAddedProvidersKeepsStatesIsolated(using: harness)
    }

    @MainActor
    private static func testDefaultsToDeepSeekProvider(using harness: TestHarness) {
        let coordinator = makeCoordinator()

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek], "coordinator default added providers")
        harness.expectEqual(coordinator.primaryProviderID, .deepseek, "coordinator default primary")
        harness.expectEqual(coordinator.availableProviderIDsToAdd, [.zhipuCodingPlan], "coordinator default available providers")
    }

    @MainActor
    private static func testAddSetPrimaryAndRemoveProvider(using harness: TestHarness) {
        let preferences = InMemoryProviderPreferencesStore()
        let coordinator = makeCoordinator(preferences: preferences)

        coordinator.addProvider(.zhipuCodingPlan)
        coordinator.setPrimaryProvider(.zhipuCodingPlan)

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek, .zhipuCodingPlan], "coordinator adds zhipu")
        harness.expectEqual(coordinator.primaryProviderID, .zhipuCodingPlan, "coordinator sets zhipu primary")
        harness.expectEqual(preferences.addedProviderIDs, [.deepseek, .zhipuCodingPlan], "coordinator persists added providers")
        harness.expectEqual(preferences.primaryProviderID, .zhipuCodingPlan, "coordinator persists primary")

        coordinator.removeProvider(.zhipuCodingPlan, deletingCredential: false)

        harness.expectEqual(coordinator.addedProviderIDs, [.deepseek], "coordinator removes zhipu")
        harness.expectEqual(coordinator.primaryProviderID, .deepseek, "coordinator primary falls back to deepseek")
    }

    @MainActor
    private static func testRemovingProviderCanDeleteCredential(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["zhipu-coding-plan-api-key": "test-key"])
        let coordinator = makeCoordinator(credentialStore: store)

        coordinator.addProvider(.zhipuCodingPlan)
        coordinator.removeProvider(.zhipuCodingPlan, deletingCredential: true)

        harness.expectEqual(try? store.credential(forAccount: "zhipu-coding-plan-api-key"), nil, "coordinator removes provider credential")
    }

    @MainActor
    private static func testRefreshAddedProvidersKeepsStatesIsolated(using harness: TestHarness) async {
        let deepSeekSnapshot = makeSnapshot(providerID: .deepseek, total: "68.65")
        let zhipuSnapshot = PlanUsageSnapshot(
            providerID: .zhipuCodingPlan,
            windowLabel: "5h",
            usagePercentage: Decimal(17),
            resetAt: nil,
            isAvailable: true,
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let deepSeek = MockBalanceProvider(
            id: .deepseek,
            displayName: "DeepSeek",
            menuPrefix: "DS",
            credentialAccount: "deepseek-api-key",
            homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
            results: [.success(.balance(deepSeekSnapshot))]
        )
        let zhipu = MockBalanceProvider(
            id: .zhipuCodingPlan,
            displayName: "Zhipu GLM Coding Plan",
            menuPrefix: "GLM",
            credentialAccount: "zhipu-coding-plan-api-key",
            homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
            results: [.success(.planUsage(zhipuSnapshot))]
        )
        let store = InMemoryCredentialStore(credentialsByAccount: [
            "deepseek-api-key": "deepseek-key",
            "zhipu-coding-plan-api-key": "zhipu-key"
        ])
        let coordinator = MultiProviderBalanceCoordinator(
            providers: [deepSeek, zhipu],
            credentialStore: store,
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [.deepseek, .zhipuCodingPlan])
        )

        await coordinator.refreshAddedProviders()

        harness.expectEqual(coordinator.state(for: .deepseek), .loaded(.balance(deepSeekSnapshot)), "coordinator deepseek state")
        harness.expectEqual(coordinator.state(for: .zhipuCodingPlan), .loaded(.planUsage(zhipuSnapshot)), "coordinator zhipu state")
        harness.expectEqual(deepSeek.lastAPIKey, "deepseek-key", "coordinator deepseek key")
        harness.expectEqual(zhipu.lastAPIKey, "zhipu-key", "coordinator zhipu key")
    }

    @MainActor
    private static func makeCoordinator(
        credentialStore: CredentialStore = InMemoryCredentialStore(),
        preferences: ProviderPreferencesStore = InMemoryProviderPreferencesStore()
    ) -> MultiProviderBalanceCoordinator {
        MultiProviderBalanceCoordinator(
            providers: [
                MockBalanceProvider(
                    id: .deepseek,
                    displayName: "DeepSeek",
                    menuPrefix: "DS",
                    credentialAccount: "deepseek-api-key",
                    homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
                    results: []
                ),
                MockBalanceProvider(
                    id: .zhipuCodingPlan,
                    displayName: "Zhipu GLM Coding Plan",
                    menuPrefix: "GLM",
                    credentialAccount: "zhipu-coding-plan-api-key",
                    homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
                    results: []
                )
            ],
            credentialStore: credentialStore,
            preferences: preferences
        )
    }
}
