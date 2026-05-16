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
        testConfiguredKeyIsNotLoadedIntoInput(using: harness)
        testConfiguredKeyWithoutSnapshotShowsPlaceholderTitle(using: harness)
        testConfiguredKeyEditorIsCollapsedByDefault(using: harness)
        testToggleAPIKeyEditorExpandsConfiguredEditor(using: harness)
        testSetupGuidanceShowsWhenKeyIsMissing(using: harness)
        testAuthenticationFailureExposesKeyRecoveryActions(using: harness)
        testRateLimitExposesRetryAction(using: harness)
        testRefreshingDisablesRefresh(using: harness)
        testRequestingAPIKeyDeletionShowsConfirmation(using: harness)
        testCancelingAPIKeyDeletionHidesConfirmationAndKeepsKey(using: harness)
        await testSavingAPIKeyClearsInputAndRefreshes(using: harness)
        await testSavingAPIKeyShowsSafeSuccessFeedback(using: harness)
        await testSaveFailureKeepsInput(using: harness)
        await testSavingEmptyAPIKeyShowsErrorFeedback(using: harness)
        await testConfirmingAPIKeyDeletionDeletesCredential(using: harness)
        await testDeletingAPIKeyReturnsToSetup(using: harness)
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
    private static func testConfiguredKeyIsNotLoadedIntoInput(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .notConfigured, credentialStore: store)

        harness.expectEqual(viewModel.apiKeyInput, "", "configured key input stays empty")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "configured status text")
    }

    @MainActor
    private static func testConfiguredKeyWithoutSnapshotShowsPlaceholderTitle(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .notConfigured, credentialStore: store)

        harness.expectEqual(viewModel.menuBarTitle, "DS --", "configured key placeholder title")
    }

    @MainActor
    private static func testConfiguredKeyEditorIsCollapsedByDefault(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        harness.expectTrue(!viewModel.shouldShowAPIKeyEditor, "configured key editor collapsed by default")
    }

    @MainActor
    private static func testToggleAPIKeyEditorExpandsConfiguredEditor(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "saved-secret-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        viewModel.toggleAPIKeyEditor()

        harness.expectTrue(viewModel.shouldShowAPIKeyEditor, "configured key editor expands after toggle")
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

        harness.expectEqual(viewModel.recoveryActions, [.replaceKey, .deleteKey], "auth failure actions")
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
    private static func testRequestingAPIKeyDeletionShowsConfirmation(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        viewModel.requestAPIKeyDeletion()

        harness.expectTrue(
            viewModel.isAPIKeyDeleteConfirmationPresented,
            "requesting api key deletion shows confirmation"
        )
    }

    @MainActor
    private static func testCancelingAPIKeyDeletionHidesConfirmationAndKeepsKey(using harness: TestHarness) {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        viewModel.requestAPIKeyDeletion()
        viewModel.cancelAPIKeyDeletion()

        harness.expectTrue(
            !viewModel.isAPIKeyDeleteConfirmationPresented,
            "canceling api key deletion hides confirmation"
        )
        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), "test-key", "cancel keeps api key")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "cancel keeps credential configured")
    }

    @MainActor
    private static func testSavingAPIKeyClearsInputAndRefreshes(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(snapshot)])
        let store = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)
        let viewModel = MenuBarBalanceViewModel(provider: provider, credentialStore: store, controller: controller)
        viewModel.apiKeyInput = "test-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "", "api key input clears after save")
        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), "test-key", "api key saved")
        harness.expectEqual(provider.lastAPIKey, "test-key", "save triggers refresh")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "credential configured after save")
        harness.expectEqual(viewModel.menuBarTitle, "DS ¥68.6", "menu title after save refresh")
    }

    @MainActor
    private static func testSavingAPIKeyShowsSafeSuccessFeedback(using harness: TestHarness) async {
        let snapshot = makeSnapshot(total: "68.65")
        let provider = MockBalanceProvider(results: [.success(snapshot)])
        let store = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)
        let viewModel = MenuBarBalanceViewModel(provider: provider, credentialStore: store, controller: controller)
        viewModel.apiKeyInput = "test-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(
            viewModel.settingsFeedback,
            SettingsFeedback(kind: .success, message: "Saved securely."),
            "structured safe save feedback"
        )
        harness.expectEqual(viewModel.settingsMessage, "Saved securely.", "derived safe save message")
    }

    @MainActor
    private static func testSaveFailureKeepsInput(using harness: TestHarness) async {
        let provider = MockBalanceProvider(results: [.failure(BalanceProviderError.authenticationFailed)])
        let store = InMemoryCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: store)
        let viewModel = MenuBarBalanceViewModel(provider: provider, credentialStore: store, controller: controller)
        viewModel.apiKeyInput = "bad-key"

        await viewModel.saveAPIKey()

        harness.expectEqual(viewModel.apiKeyInput, "bad-key", "save failure keeps input")
        harness.expectTrue(viewModel.shouldShowAPIKeyEditor, "save failure keeps editor expanded")
        harness.expectEqual(viewModel.credentialStatusText, "Configured", "credential configured after save failure")
        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), "bad-key", "bad key remains saved")
        harness.expectEqual(viewModel.settingsFeedback?.kind, .warning, "save failure warning feedback")
        harness.expectTrue(
            viewModel.settingsFeedback?.message.contains("bad-key") == false,
            "save failure feedback does not expose key"
        )
    }

    @MainActor
    private static func testSavingEmptyAPIKeyShowsErrorFeedback(using harness: TestHarness) async {
        let viewModel = makeViewModel(state: .notConfigured)
        viewModel.apiKeyInput = "   "

        await viewModel.saveAPIKey()

        harness.expectEqual(
            viewModel.settingsFeedback,
            SettingsFeedback(kind: .error, message: "API key is required."),
            "empty key error feedback"
        )
        harness.expectEqual(viewModel.settingsMessage, "API key is required.", "empty key derived message")
    }

    @MainActor
    private static func testConfirmingAPIKeyDeletionDeletesCredential(using harness: TestHarness) async {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        viewModel.requestAPIKeyDeletion()
        await viewModel.confirmAPIKeyDeletion()

        harness.expectTrue(
            !viewModel.isAPIKeyDeleteConfirmationPresented,
            "confirming api key deletion hides confirmation"
        )
        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), nil, "confirm deletes api key")
        harness.expectEqual(viewModel.credentialStatusText, "Not configured", "confirm updates credential status")
    }

    @MainActor
    private static func testDeletingAPIKeyReturnsToSetup(using harness: TestHarness) async {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        await viewModel.deleteAPIKey()

        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), nil, "api key deleted")
        harness.expectEqual(viewModel.credentialStatusText, "Not configured", "credential status after delete")
        harness.expectEqual(viewModel.menuBarTitle, "DS Setup", "menu title after delete")
        harness.expectEqual(
            viewModel.settingsFeedback,
            SettingsFeedback(kind: .success, message: "API key deleted."),
            "delete success feedback"
        )
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
