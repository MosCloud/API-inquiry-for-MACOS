import APIInquiryCore
import AppKit
import Combine
import SwiftUI

@MainActor
final class UsageConsoleWindowController: ObservableObject {
    private let viewModel: UsageConsoleViewModel
    private let languageStore: AppLanguageStore
    private var window: NSWindow?
    private var glassHostingController: UsageConsoleGlassHostingController?
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

        if let window, let glassHostingController {
            glassHostingController.rootView = rootView
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        } else if let window {
            let glassHostingController = UsageConsoleGlassHostingController(rootView: rootView)
            window.contentViewController = glassHostingController
            self.glassHostingController = glassHostingController
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        let glassHostingController = UsageConsoleGlassHostingController(rootView: rootView)
        window.contentViewController = glassHostingController
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        self.glassHostingController = glassHostingController

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private final class UsageConsoleGlassHostingController: NSViewController {
    private let hostingController: NSHostingController<UsageConsoleView>

    var rootView: UsageConsoleView {
        get {
            hostingController.rootView
        }
        set {
            hostingController.rootView = newValue
        }
    }

    init(rootView: UsageConsoleView) {
        hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let backdropView = makeBackdropView()
        view = backdropView

        addChild(hostingController)
        attachHostingView(to: backdropView)
    }

    private func makeBackdropView() -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.cornerRadius = 0
            glassView.tintColor = NSColor(calibratedWhite: 0.92, alpha: 0.08)
            return glassView
        }

        let effectView = NSVisualEffectView()
        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        return effectView
    }

    private func attachHostingView(to backdropView: NSView) {
        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false

        if #available(macOS 26.0, *), let glassView = backdropView as? NSGlassEffectView {
            glassView.contentView = hostingView
        } else {
            backdropView.addSubview(hostingView)
        }

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: backdropView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor)
        ])
    }
}
