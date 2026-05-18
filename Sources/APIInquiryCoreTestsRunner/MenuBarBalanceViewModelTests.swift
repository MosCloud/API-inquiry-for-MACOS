import APIInquiryCore
import Foundation

enum MenuBarBalanceViewModelTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testLoadedMenuTitleFormatting(using: harness)
        testLoadedMenuBarValueFormatting(using: harness)
        testFailedStatePreservesMenuTitle(using: harness)
        testPanelBalanceTextFormatting(using: harness)
        testPanelBalanceDisplayParts(using: harness)
        testStatusText(using: harness)
        testConfiguredKeyWithoutSnapshotShowsPlaceholderTitle(using: harness)
        testCredentialChangesFromConsoleAreReflected(using: harness)
        testSetupGuidanceShowsWhenKeyIsMissing(using: harness)
        testAuthenticationFailureExposesKeyRecoveryActions(using: harness)
        testRateLimitExposesRetryAction(using: harness)
        testRefreshingDisablesRefresh(using: harness)
        await testZhipuPrimaryProviderFormatsPlanUsage(using: harness)
        await testSecondaryProviderRowsExposeOtherProviders(using: harness)
    }

    @MainActor
    private static func testZhipuPrimaryProviderFormatsPlanUsage(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .zhipuCodingPlan, resetAt: sampleResetDate)
        await coordinator.refresh(.zhipuCodingPlan)
        let viewModel = MenuBarBalanceViewModel(
            coordinator: coordinator,
            lastRefreshTimeFormatter: fixedTimeFormatter
        )

        harness.expectEqual(viewModel.menuBarValueText, "5h 17%", "zhipu menu bar value")
        harness.expectEqual(viewModel.menuBarTitle, "GLM 5h 17%", "zhipu menu bar title")
        harness.expectEqual(viewModel.primaryDisplayParts.providerID, .zhipuCodingPlan, "zhipu primary display id")
        harness.expectEqual(viewModel.primaryDisplayParts.captionText, "5h", "zhipu primary display caption")
        harness.expectEqual(viewModel.primaryDisplayParts.amountText, "17", "zhipu primary display amount")
        harness.expectEqual(viewModel.primaryDisplayParts.trailingText, "% used", "zhipu primary display trailing")
        harness.expectEqual(viewModel.resetText, "Resets: 23:05", "zhipu reset text")
        harness.expectEqual(viewModel.statusText, "Plan available", "zhipu primary status")
    }

    @MainActor
    private static func testSecondaryProviderRowsExposeOtherProviders(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .zhipuCodingPlan)
        await coordinator.refreshAddedProviders()
        let viewModel = MenuBarBalanceViewModel(coordinator: coordinator)

        harness.expectEqual(viewModel.secondaryProviderRows.count, 1, "secondary provider row count")
        harness.expectEqual(viewModel.secondaryProviderRows.first?.providerID, .deepseek, "secondary provider row id")
        harness.expectEqual(viewModel.secondaryProviderRows.first?.detailText, "¥68.65 CNY", "secondary provider detail")
        harness.expectEqual(viewModel.secondaryProviderRows.first?.statusText, "Available", "secondary provider status")
    }

    @MainActor
    private static func testLoadedMenuTitleFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(.balance(makeSnapshot(total: "68.65"))))

        harness.expectEqual(viewModel.menuBarTitle, "DS ¥68.6", "loaded menu title")
    }

    @MainActor
    private static func testLoadedMenuBarValueFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(.balance(makeSnapshot(total: "68.65"))))

        harness.expectEqual(viewModel.menuBarValueText, "¥68.6", "loaded menu bar value")
    }

    @MainActor
    private static func testFailedStatePreservesMenuTitle(using harness: TestHarness) {
        let viewModel = makeViewModel(
            state: .failed(message: "Refresh failed.", kind: .unknown, last: .balance(makeSnapshot(total: "68.65")))
        )

        harness.expectEqual(viewModel.menuBarTitle, "DS ¥68.6", "failed menu title keeps last balance")
    }

    @MainActor
    private static func testPanelBalanceTextFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(.balance(makeSnapshot(total: "68.65"))))

        harness.expectEqual(viewModel.panelBalanceText, "¥68.65 CNY", "panel balance text")
    }

    @MainActor
    private static func testPanelBalanceDisplayParts(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(.balance(makeSnapshot(total: "68.65"))))

        harness.expectEqual(viewModel.panelBalanceDisplayParts.leadingText, "¥", "panel balance leading text")
        harness.expectEqual(viewModel.panelBalanceDisplayParts.amountText, "68.65", "panel balance amount text")
        harness.expectEqual(viewModel.panelBalanceDisplayParts.trailingText, "CNY", "panel balance trailing text")
    }

    @MainActor
    private static func testStatusText(using harness: TestHarness) {
        harness.expectEqual(makeViewModel(state: .notConfigured).statusText, "Not configured", "not configured status")
        harness.expectEqual(makeViewModel(state: .loading(last: nil)).statusText, "Refreshing", "refreshing status")
        harness.expectEqual(makeViewModel(state: .loaded(.balance(makeSnapshot(total: "0.00", isAvailable: false)))).statusText, "Balance insufficient", "insufficient status")
        harness.expectEqual(makeViewModel(state: .failed(message: "Refresh failed.", kind: .unknown, last: nil)).statusText, "Unavailable", "failed status")
        harness.expectEqual(makeViewModel(state: .loading(last: nil)).statusTone, .refreshing, "refreshing status tone")
        harness.expectEqual(makeViewModel(state: .loaded(.balance(makeSnapshot(total: "68.65")))).statusTone, .success, "available status tone")
        harness.expectEqual(makeViewModel(state: .failed(message: "Refresh failed.", kind: .unknown, last: nil)).statusTone, .warning, "failed status tone")
    }

    @MainActor
    private static func testConfiguredKeyWithoutSnapshotShowsPlaceholderTitle(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .notConfigured, credentialStore: store)

        harness.expectEqual(viewModel.menuBarTitle, "DS --", "configured key placeholder title")
    }

    @MainActor
    private static func testCredentialChangesFromConsoleAreReflected(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .notConfigured, credentialStore: store)

        try? store.deleteCredential(forAccount: "deepseek-api-key")

        harness.expectEqual(viewModel.menuBarTitle, "DS Setup", "menu title reflects deleted key")
        harness.expectTrue(viewModel.shouldShowSetupGuidance, "setup guidance reflects deleted key")
    }

    @MainActor
    private static func testSetupGuidanceShowsWhenKeyIsMissing(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .notConfigured)

        harness.expectTrue(viewModel.shouldShowSetupGuidance, "setup guidance visible without key")
        harness.expectEqual(
            viewModel.setupGuidanceText,
            "Add a DeepSeek API key to start checking your balance.",
            "setup guidance text"
        )
    }

    @MainActor
    private static func testAuthenticationFailureExposesKeyRecoveryActions(using harness: TestHarness) {
        let viewModel = makeViewModel(
            state: .failed(
                message: "API key may be invalid. Replace or delete it in the console.",
                kind: .authenticationFailed,
                last: nil
            ),
            credentialStore: InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "bad-key"])
        )

        harness.expectEqual(viewModel.recoveryActions, [.openConsole], "auth failure opens console")
    }

    @MainActor
    private static func testRateLimitExposesRetryAction(using harness: TestHarness) {
        let viewModel = makeViewModel(
            state: .failed(
                message: "Balance API rate limit reached. Try again shortly.",
                kind: .rateLimited,
                last: .balance(makeSnapshot(total: "68.65"))
            )
        )

        harness.expectEqual(viewModel.recoveryActions, [.retry], "rate limit retry action")
    }

    @MainActor
    private static func testRefreshingDisablesRefresh(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loading(last: .balance(makeSnapshot(total: "68.65"))))

        harness.expectTrue(viewModel.isRefreshDisabled, "refresh disabled while loading")
    }

    @MainActor
    private static func makeViewModel(
        state: BalanceState,
        credentialStore: CredentialStore = InMemoryCredentialStore()
    ) -> MenuBarBalanceViewModel {
        let provider = MockBalanceProvider(results: [])
        let controller = BalanceRefreshController(
            provider: provider,
            credentialStore: credentialStore,
            initialState: state
        )
        return MenuBarBalanceViewModel(provider: provider, credentialStore: credentialStore, controller: controller)
    }

    @MainActor
    private static func makeMultiProviderCoordinator(
        primaryProviderID: ProviderID,
        resetAt: Date? = nil
    ) -> MultiProviderBalanceCoordinator {
        let deepSeekSnapshot = makeSnapshot(providerID: .deepseek, total: "68.65")
        let zhipuSnapshot = PlanUsageSnapshot(
            providerID: .zhipuCodingPlan,
            windowLabel: "5h",
            usagePercentage: Decimal(17),
            resetAt: resetAt,
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
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "zhipu-coding-plan-api-key": "zhipu-key"
            ]),
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek, .zhipuCodingPlan],
                primaryProviderID: primaryProviderID
            )
        )
    }

    private static var fixedTimeFormatter: LastRefreshTimeFormatter {
        LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
    }

    private static var sampleResetDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 23
        components.minute = 5
        return components.date!
    }
}
