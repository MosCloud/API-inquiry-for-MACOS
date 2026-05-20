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
        testChineseStatusText(using: harness)
        testConfiguredKeyWithoutSnapshotShowsPlaceholderTitle(using: harness)
        testCredentialChangesFromConsoleAreReflected(using: harness)
        testSetupGuidanceShowsWhenKeyIsMissing(using: harness)
        testChineseSetupGuidanceUsesAPIKeyTerminology(using: harness)
        testAuthenticationFailureExposesKeyRecoveryActions(using: harness)
        testRateLimitExposesRetryAction(using: harness)
        testRefreshingDisablesRefresh(using: harness)
        await testZhipuPrimaryProviderFormatsPlanUsage(using: harness)
        await testCodexPrimaryProviderFormatsQuotaUsage(using: harness)
        await testCodexPrimaryProviderFormatsChineseQuotaLabels(using: harness)
        await testCodexSecondaryProviderRowsExposeQuotaUsage(using: harness)
        await testSecondaryProviderRowsExposeOtherProviders(using: harness)
        await testZhipuSecondaryProviderRowsOmitUsedSuffix(using: harness)
        await testRefreshUpdatesAllAddedProviders(using: harness)
    }

    @MainActor
    private static func testCodexPrimaryProviderFormatsQuotaUsage(using harness: TestHarness) async {
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex)
        await coordinator.refresh(.codex)
        let viewModel = MenuBarBalanceViewModel(
            coordinator: coordinator,
            lastRefreshTimeFormatter: fixedTimeFormatter
        )

        harness.expectEqual(viewModel.menuBarValueText, "5h 72%", "codex menu bar value")
        harness.expectEqual(viewModel.menuBarTitle, "5h 72%", "codex menu bar title has no provider prefix")
        harness.expectEqual(viewModel.primaryDisplayParts.providerID, .codex, "codex primary display id")
        harness.expectEqual(viewModel.primaryDisplayParts.captionText, "5h", "codex primary display caption")
        harness.expectEqual(viewModel.primaryDisplayParts.amountText, "72", "codex primary display amount")
        harness.expectEqual(viewModel.primaryDisplayParts.trailingText, "% remaining", "codex primary display trailing")
        harness.expectEqual(viewModel.statusText, "Quota available", "codex primary status")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.count, 2, "codex quota row count")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.label, "5h", "codex primary quota row label")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.amountText, "72", "codex primary quota row amount")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.suffixText, "% remg", "codex primary quota row suffix")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.detailText, "72% remg", "codex primary quota row detail")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.resetText, "Resets: 23:05", "codex primary quota reset")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.label, "7d", "codex weekly quota row label")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.amountText, "48", "codex weekly quota row amount")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.suffixText, "% remg", "codex weekly quota row suffix")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.detailText, "48% remg", "codex weekly quota row detail")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.resetText, "Resets: 05/18", "codex weekly quota reset")
    }

    @MainActor
    private static func testCodexSecondaryProviderRowsExposeQuotaUsage(using harness: TestHarness) async {
        let coordinator = makeCodexCoordinator(primaryProviderID: .deepseek)
        await coordinator.refreshAddedProviders()
        let viewModel = MenuBarBalanceViewModel(
            coordinator: coordinator,
            lastRefreshTimeFormatter: fixedTimeFormatter
        )

        let codexRow = viewModel.secondaryProviderRows.first { $0.providerID == .codex }
        harness.expectEqual(codexRow?.displayName, "OpenAI", "codex secondary row display name")
        harness.expectEqual(codexRow?.detailText, "5h 72%", "codex secondary row detail")
        harness.expectEqual(codexRow?.quotaWindowRows.count, 2, "codex secondary quota row count")
        harness.expectEqual(codexRow?.quotaWindowRows.first?.label, "5h", "codex secondary first quota label")
        harness.expectEqual(codexRow?.quotaWindowRows.first?.detailText, "72%", "codex secondary first quota detail")
        harness.expectEqual(codexRow?.quotaWindowRows.first?.resetText, "Resets: 23:05", "codex secondary first quota reset")
        harness.expectEqual(codexRow?.quotaWindowRows.last?.label, "7d", "codex secondary weekly quota label")
        harness.expectEqual(codexRow?.quotaWindowRows.last?.detailText, "48%", "codex secondary weekly quota detail")
        harness.expectEqual(codexRow?.quotaWindowRows.last?.resetText, "Resets: 05/18", "codex secondary weekly quota reset")
        harness.expectEqual(codexRow?.statusText, "Quota available", "codex secondary row status")
    }

    @MainActor
    private static func testCodexPrimaryProviderFormatsChineseQuotaLabels(using harness: TestHarness) async {
        let coordinator = makeCodexCoordinator(primaryProviderID: .codex)
        await coordinator.refresh(.codex)
        let viewModel = MenuBarBalanceViewModel(
            coordinator: coordinator,
            lastRefreshTimeFormatter: fixedTimeFormatter,
            languageStore: makeLanguageStore(selection: .zh)
        )

        harness.expectEqual(viewModel.statusText, "额度可用", "chinese codex status")
        harness.expectEqual(viewModel.menuBarValueText, "5h 72%", "chinese codex menu bar keeps compact official label")
        harness.expectEqual(viewModel.menuBarTitle, "5h 72%", "chinese codex menu bar title keeps compact official label")
        harness.expectEqual(viewModel.primaryDisplayParts.captionText, "5 时", "chinese codex primary caption")
        harness.expectEqual(viewModel.primaryDisplayParts.trailingText, "% 剩余", "chinese codex trailing")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.label, "5 时", "chinese codex first quota label")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.suffixText, "% 剩余", "chinese codex first quota suffix")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.detailText, "72% 剩余", "chinese codex first quota detail")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.first?.resetText, "重置于：23:05", "chinese codex first quota reset")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.label, "1 周", "chinese codex weekly quota label")
        harness.expectEqual(viewModel.primaryQuotaWindowRows.last?.resetText, "重置于：05/18", "chinese codex weekly quota reset")
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
    private static func testZhipuSecondaryProviderRowsOmitUsedSuffix(using harness: TestHarness) async {
        let coordinator = makeMultiProviderCoordinator(primaryProviderID: .deepseek, resetAt: sampleResetDate)
        await coordinator.refreshAddedProviders()
        let viewModel = MenuBarBalanceViewModel(
            coordinator: coordinator,
            lastRefreshTimeFormatter: fixedTimeFormatter
        )

        let zhipuRow = viewModel.secondaryProviderRows.first { $0.providerID == .zhipuCodingPlan }
        harness.expectEqual(zhipuRow?.detailText, "5h 17%", "zhipu secondary row detail omits used")
        harness.expectEqual(zhipuRow?.resetText, "Resets: 23:05", "zhipu secondary row reset")
    }

    @MainActor
    private static func testRefreshUpdatesAllAddedProviders(using harness: TestHarness) async {
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
                resetAt: sampleResetDate,
                isAvailable: true,
                fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
            )))]
        )
        let coordinator = MultiProviderBalanceCoordinator(
            providers: [deepSeek, zhipu],
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "zhipu-coding-plan-api-key": "zhipu-key"
            ]),
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek, .zhipuCodingPlan],
                primaryProviderID: .zhipuCodingPlan
            )
        )
        let viewModel = MenuBarBalanceViewModel(coordinator: coordinator)

        await viewModel.refresh()

        harness.expectEqual(deepSeek.fetchCount, 1, "menu detail refresh updates secondary deepseek")
        harness.expectEqual(zhipu.fetchCount, 1, "menu detail refresh updates primary zhipu")
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
    private static func testChineseStatusText(using harness: TestHarness) {
        harness.expectEqual(makeViewModel(state: .notConfigured, languageSelection: .zh).statusText, "未配置", "chinese not configured status")
        harness.expectEqual(makeViewModel(state: .loading(last: nil), languageSelection: .zh).statusText, "刷新中", "chinese refreshing status")
        harness.expectEqual(
            makeViewModel(state: .loaded(.balance(makeSnapshot(total: "0.00", isAvailable: false))), languageSelection: .zh).statusText,
            "余额不足",
            "chinese insufficient status"
        )
        harness.expectEqual(makeViewModel(state: .failed(message: "Refresh failed.", kind: .unknown, last: nil), languageSelection: .zh).statusText, "不可用", "chinese failed status")
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
    private static func testChineseSetupGuidanceUsesAPIKeyTerminology(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .notConfigured, languageSelection: .zh)

        harness.expectEqual(
            viewModel.setupGuidanceText,
            "添加 DeepSeek API 密钥以开始查询余额。",
            "chinese setup guidance text"
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
        credentialStore: CredentialStore = InMemoryCredentialStore(),
        languageSelection: AppLanguage = .en
    ) -> MenuBarBalanceViewModel {
        let provider = MockBalanceProvider(results: [])
        let controller = BalanceRefreshController(
            provider: provider,
            credentialStore: credentialStore,
            initialState: state
        )
        return MenuBarBalanceViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller,
            languageStore: makeLanguageStore(selection: languageSelection)
        )
    }

    private static func makeLanguageStore(selection: AppLanguage) -> AppLanguageStore {
        let defaults = UserDefaults(suiteName: "APIInquiry.MenuBarBalanceViewModelTests.\(UUID().uuidString)")!
        let store = AppLanguageStore(userDefaults: defaults, preferredLanguages: { ["en-US"] })
        store.selection = selection
        return store
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

    @MainActor
    private static func makeCodexCoordinator(primaryProviderID: ProviderID) -> MultiProviderBalanceCoordinator {
        MultiProviderBalanceCoordinator(
            providers: [
                MockBalanceProvider(
                    id: .deepseek,
                    displayName: "DeepSeek",
                    menuPrefix: "DS",
                    credentialAccount: "deepseek-api-key",
                    homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
                    results: [.success(.balance(makeSnapshot(providerID: .deepseek, total: "68.65")))]
                ),
                MockBalanceProvider(
                    id: .codex,
                    displayName: "Codex",
                    menuPrefix: "GPT",
                    credentialAccount: "codex-session-token",
                    homepageURL: URL(string: "https://chatgpt.com/codex/settings/usage")!,
                    results: [.success(.quotaUsage(makeCodexSnapshot()))]
                )
            ],
            credentialStore: InMemoryCredentialStore(credentialsByAccount: [
                "deepseek-api-key": "deepseek-key",
                "codex-session-token": "codex-token"
            ]),
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek, .codex],
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

    private static var sampleWeeklyResetDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 18
        components.hour = 19
        components.minute = 7
        return components.date!
    }

    private static func makeCodexSnapshot() -> QuotaUsageSnapshot {
        QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(
                    label: "5h",
                    remainingPercentage: Decimal(72),
                    resetAt: sampleResetDate,
                    isAvailable: true
                ),
                QuotaWindowSnapshot(
                    label: "Week",
                    remainingPercentage: Decimal(48),
                    resetAt: sampleWeeklyResetDate,
                    isAvailable: true
                )
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
    }
}
