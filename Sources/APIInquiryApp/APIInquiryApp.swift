import APIInquiryCore
import AppKit
import SwiftUI

@main
struct APIInquiryApp: App {
    @StateObject private var viewModel: MenuBarBalanceViewModel

    init() {
        NSApp.setActivationPolicy(.accessory)

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
