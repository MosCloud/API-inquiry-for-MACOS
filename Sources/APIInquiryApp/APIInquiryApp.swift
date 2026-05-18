import APIInquiryCore
import AppKit
import SwiftUI

@main
struct APIInquiryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarBalanceViewModel
    @StateObject private var consoleViewModel: UsageConsoleViewModel
    @StateObject private var consoleWindowController: UsageConsoleWindowController

    init() {
        let providers: [BalanceProvider] = [
            DeepSeekBalanceProvider(),
            ZhipuCodingPlanProvider()
        ]
        let credentialStore = KeychainCredentialStore()
        let coordinator = MultiProviderBalanceCoordinator(
            providers: providers,
            credentialStore: credentialStore,
            preferences: UserDefaultsProviderPreferencesStore()
        )
        let viewModel = MenuBarBalanceViewModel(coordinator: coordinator)
        let consoleViewModel = UsageConsoleViewModel(coordinator: coordinator, credentialStore: credentialStore)

        _viewModel = StateObject(wrappedValue: viewModel)
        _consoleViewModel = StateObject(wrappedValue: consoleViewModel)
        _consoleWindowController = StateObject(
            wrappedValue: UsageConsoleWindowController(viewModel: consoleViewModel)
        )

        Task { @MainActor in
            await coordinator.refreshAddedProviders()
            viewModel.startAutoRefresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel) { section in
                consoleWindowController.open(defaultSection: section)
            }
        } label: {
            Image(nsImage: DeepSeekImages.menuBarLabelImage(
                text: viewModel.menuBarValueText,
                providerID: viewModel.primaryDisplayParts.providerID,
                providerPrefix: viewModel.menuBarTitle.components(separatedBy: " ").first ?? "API"
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
