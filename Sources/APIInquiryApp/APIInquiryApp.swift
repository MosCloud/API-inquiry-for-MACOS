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
        let provider = DeepSeekBalanceProvider()
        let credentialStore = KeychainCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        let viewModel = MenuBarBalanceViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )
        let consoleViewModel = UsageConsoleViewModel(
            provider: provider,
            credentialStore: credentialStore,
            controller: controller
        )

        _viewModel = StateObject(wrappedValue: viewModel)
        _consoleViewModel = StateObject(wrappedValue: consoleViewModel)
        _consoleWindowController = StateObject(
            wrappedValue: UsageConsoleWindowController(viewModel: consoleViewModel)
        )

        Task { @MainActor in
            await viewModel.refresh()
            viewModel.startAutoRefresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel) { section in
                consoleWindowController.open(defaultSection: section)
            }
        } label: {
            Image(nsImage: DeepSeekImages.menuBarLabelImage(text: viewModel.menuBarValueText))
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
