import APIInquiryCore
import AppKit
import SwiftUI

@main
struct APIInquiryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarBalanceViewModel
    @StateObject private var consoleViewModel: UsageConsoleViewModel
    @StateObject private var consoleWindowController: UsageConsoleWindowController
    @StateObject private var languageStore: AppLanguageStore

    init() {
        let languageStore = AppLanguageStore()
        let providers = BuiltInProviderRegistry.default.makeProviders()
        let credentialStore = CodexCredentialStore(delegate: KeychainCredentialStore())
        let coordinator = MultiProviderBalanceCoordinator(
            providers: providers,
            credentialStore: credentialStore,
            preferences: UserDefaultsProviderPreferencesStore(),
            localizedStrings: { LocalizedStrings(language: languageStore.resolvedLanguage) }
        )
        let viewModel = MenuBarBalanceViewModel(coordinator: coordinator, languageStore: languageStore)
        let consoleViewModel = UsageConsoleViewModel(
            coordinator: coordinator,
            credentialStore: credentialStore,
            languageStore: languageStore
        )

        _languageStore = StateObject(wrappedValue: languageStore)
        _viewModel = StateObject(wrappedValue: viewModel)
        _consoleViewModel = StateObject(wrappedValue: consoleViewModel)
        _consoleWindowController = StateObject(
            wrappedValue: UsageConsoleWindowController(viewModel: consoleViewModel, languageStore: languageStore)
        )

        Task { @MainActor in
            await coordinator.refreshAddedProviders()
            viewModel.startAutoRefresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel, languageStore: languageStore) { section in
                consoleWindowController.open(defaultSection: section)
            }
        } label: {
            Image(nsImage: DeepSeekImages.menuBarLabelImage(
                text: viewModel.menuBarValueText,
                providerID: viewModel.primaryDisplayParts.providerID,
                providerPrefix: viewModel.primaryDisplayParts.providerID == .codex
                    ? "GPT"
                    : viewModel.menuBarTitle.components(separatedBy: " ").first ?? "API"
            ))
                .renderingMode(.template)
                .accessibilityLabel("\(viewModel.providerDisplayName) \(viewModel.menuBarValueText)")
        }
        .menuBarExtraStyle(.window)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
