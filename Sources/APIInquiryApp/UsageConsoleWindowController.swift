import APIInquiryCore
import AppKit
import Combine
import SwiftUI

@MainActor
final class UsageConsoleWindowController: ObservableObject {
    private let viewModel: UsageConsoleViewModel
    private let languageStore: AppLanguageStore
    private var window: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    init(viewModel: UsageConsoleViewModel, languageStore: AppLanguageStore = AppLanguageStore()) {
        self.viewModel = viewModel
        self.languageStore = languageStore

        languageStore.$selection
            .sink { [weak self, weak languageStore] selection in
                guard let languageStore else {
                    return
                }
                self?.window?.title = LocalizedStrings(
                    language: languageStore.resolvedLanguage(for: selection)
                ).appConsoleTitle
            }
            .store(in: &cancellables)
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
        window.title = LocalizedStrings(language: languageStore.resolvedLanguage).appConsoleTitle
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
