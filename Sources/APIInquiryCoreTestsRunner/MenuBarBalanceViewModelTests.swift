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
        await testSavingAPIKeyClearsInputAndRefreshes(using: harness)
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
            state: .failed(message: "Refresh failed.", last: makeSnapshot(total: "68.65"))
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
        harness.expectEqual(makeViewModel(state: .failed(message: "Refresh failed.", last: nil)).statusText, "Refresh failed", "failed status")
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
    private static func testDeletingAPIKeyReturnsToSetup(using harness: TestHarness) async {
        let store = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "test-key"])
        let viewModel = makeViewModel(state: .loaded(makeSnapshot(total: "68.65")), credentialStore: store)

        await viewModel.deleteAPIKey()

        harness.expectEqual(try? store.credential(forAccount: "deepseek-api-key"), nil, "api key deleted")
        harness.expectEqual(viewModel.credentialStatusText, "Not configured", "credential status after delete")
        harness.expectEqual(viewModel.menuBarTitle, "DS Setup", "menu title after delete")
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
