import APIInquiryCore
import AppKit
import SwiftUI

@main
struct APIInquiryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarBalanceViewModel

    init() {
        let viewModel = MenuBarBalanceViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)

        Task { @MainActor in
            await viewModel.refresh()
            viewModel.startAutoRefresh()
        }
    }

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
