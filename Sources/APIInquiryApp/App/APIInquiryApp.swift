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
        let registry = BuiltInProviderRegistry.default
        let credentialStore = OpenCodeCredentialStore(
            delegate: CodexCredentialStore(delegate: KeychainCredentialStore())
        )
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: registry.registrations,
            credentialStore: credentialStore,
            preferences: UserDefaultsProviderPreferencesStore(),
            defaultProviderID: registry.defaultProviderID,
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
            HStack(spacing: 2) {
                Image(nsImage: ProviderVisualCatalog.menuBarLabelImage(
                    text: viewModel.menuBarValueText,
                    providerID: viewModel.primaryDisplayParts.providerID,
                    providerPrefix: viewModel.menuBarIconFallbackText
                ))
                    .renderingMode(.template)

                if viewModel.isShowingStaleValue {
                    Image(nsImage: ProviderVisualCatalog.staleMarkerImage())
                        .renderingMode(.original)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(viewModel.menuBarAccessibilityText)
        }
        .menuBarExtraStyle(.window)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
