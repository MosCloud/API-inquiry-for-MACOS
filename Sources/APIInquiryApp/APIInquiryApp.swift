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
            HStack(spacing: 4) {
                Image("deepseek-menu-icon-template", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)

                Text(viewModel.menuBarValueText)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
