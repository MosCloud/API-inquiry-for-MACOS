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
    }

    @MainActor
    private static func testLoadedMenuTitleFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")))

        harness.expectEqual(viewModel.menuBarTitle, "DS ¥68.6", "loaded menu title")
    }

    @MainActor
    private static func testLoadedMenuBarValueFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")))

        harness.expectEqual(viewModel.menuBarValueText, "¥68.6", "loaded menu bar value")
    }

    @MainActor
    private static func testFailedStatePreservesMenuTitle(using harness: TestHarness) {
        let viewModel = makeViewModel(
            state: .failed(message: "Refresh failed.", kind: .unknown, last: makeSnapshot(total: "68.65"))
        )

        harness.expectEqual(viewModel.menuBarTitle, "DS ¥68.6", "failed menu title keeps last balance")
    }

    @MainActor
    private static func testPanelBalanceTextFormatting(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")))

        harness.expectEqual(viewModel.panelBalanceText, "¥68.65 CNY", "panel balance text")
    }

    @MainActor
    private static func testPanelBalanceDisplayParts(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")))

        harness.expectEqual(viewModel.panelBalanceDisplayParts.leadingText, "¥", "panel balance leading text")
        harness.expectEqual(viewModel.panelBalanceDisplayParts.amountText, "68.65", "panel balance amount text")
        harness.expectEqual(viewModel.panelBalanceDisplayParts.trailingText, "CNY", "panel balance trailing text")
    }

    @MainActor
    private static func testStatusText(using harness: TestHarness) {
        harness.expectEqual(makeViewModel(state: .notConfigured).statusText, "Not configured", "not configured status")
        harness.expectEqual(makeViewModel(state: .loading(last: nil)).statusText, "Refreshing", "refreshing status")
        harness.expectEqual(makeViewModel(state: .loaded(makeSnapshot(total: "0.00", isAvailable: false))).statusText, "Balance insufficient", "insufficient status")
        harness.expectEqual(makeViewModel(state: .failed(message: "Refresh failed.", kind: .unknown, last: nil)).statusText, "Refresh failed", "failed status")
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
                message: "API key may be invalid. Replace or delete it in settings.",
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
                last: makeSnapshot(total: "68.65")
            )
        )

        harness.expectEqual(viewModel.recoveryActions, [.retry], "rate limit retry action")
    }

    @MainActor
    private static func testRefreshingDisablesRefresh(using harness: TestHarness) {
        let viewModel = makeViewModel(state: .loading(last: makeSnapshot(total: "68.65")))

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
}
