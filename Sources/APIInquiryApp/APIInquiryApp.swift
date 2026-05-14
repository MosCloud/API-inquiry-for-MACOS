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
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
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
