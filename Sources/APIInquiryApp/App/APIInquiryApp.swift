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

        // Fixtures replace the credential store and provider factory only: the
        // coordinator, view models and views are the real ones. They never activate in
        // a release build, and only when the development copy is launched with
        // `--fixtures <scenario>`.
        var fixtureScenario: FixtureScenario?
        #if DEBUG
        if let scenario = FixtureMode.scenario(from: CommandLine.arguments),
           let commit = Bundle.main.object(forInfoDictionaryKey: "APIInquiryGitCommit") as? String,
           !commit.isEmpty {
            fixtureScenario = scenario
        }
        #endif

        let credentialStore: CredentialStore
        let coordinator: MultiProviderBalanceCoordinator

        if let fixtureScenario {
            let fixture = FixtureScenarioData.make(for: fixtureScenario)
            credentialStore = fixture.credentialStore
            coordinator = MultiProviderBalanceCoordinator(
                registrations: fixture.registrations,
                credentialStore: fixture.credentialStore,
                preferences: fixture.preferences,
                defaultProviderID: fixture.defaultProviderID,
                localizedStrings: { LocalizedStrings(language: languageStore.resolvedLanguage) }
            )
        } else {
            let store = OpenCodeCredentialStore(
                delegate: CodexCredentialStore(delegate: KeychainCredentialStore())
            )
            credentialStore = store
            coordinator = MultiProviderBalanceCoordinator(
                registrations: registry.registrations,
                credentialStore: store,
                preferences: UserDefaultsProviderPreferencesStore(),
                defaultProviderID: registry.defaultProviderID,
                localizedStrings: { LocalizedStrings(language: languageStore.resolvedLanguage) }
            )
        }
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
            Image(nsImage: ProviderVisualCatalog.menuBarLabelImage(
                text: viewModel.menuBarValueText,
                providerID: viewModel.primaryDisplayParts.providerID,
                providerPrefix: viewModel.menuBarIconFallbackText,
                isStale: viewModel.isShowingStaleValue
            ))
                .renderingMode(viewModel.isShowingStaleValue ? .original : .template)
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
