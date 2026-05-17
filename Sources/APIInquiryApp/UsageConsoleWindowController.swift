import APIInquiryCore
import AppKit
import SwiftUI

@MainActor
final class UsageConsoleWindowController: ObservableObject {
    private let viewModel: UsageConsoleViewModel
    private var window: NSWindow?

    init(viewModel: UsageConsoleViewModel) {
        self.viewModel = viewModel
    }

    func open(defaultSection: UsageConsoleSection = .home) {
        let rootView = UsageConsoleView(viewModel: viewModel, initialSection: defaultSection)

        if let window {
            window.contentViewController = NSHostingController(rootView: rootView)
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "API Inquiry Console"
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
