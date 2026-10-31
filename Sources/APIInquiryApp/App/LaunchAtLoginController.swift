import APIInquiryCore
import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: AutoStartStatus
    @Published private var messageKind: MessageKind?

    private let service: LaunchAtLoginService
    private let languageStore: AppLanguageStore
    private var cancellables: Set<AnyCancellable> = []

    init(
        service: LaunchAtLoginService = MainAppLaunchAtLoginService(),
        languageStore: AppLanguageStore = AppLanguageStore()
    ) {
        self.service = service
        self.languageStore = languageStore
        self.status = service.currentStatus

        languageStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var message: String? {
        guard let messageKind else {
            return nil
        }

        switch messageKind {
        case .requiresApproval:
            return strings.approveAutoStartInSystemSettings
        case .updateFailed:
            return strings.autoStartCouldNotBeUpdated
        }
    }

    func refreshStatus() {
        status = service.currentStatus
        if status != .requiresApproval {
            messageKind = nil
        }
    }

    func toggle() {
        do {
            if isEnabled {
                try service.unregister()
            } else {
                try service.register()
            }

            status = service.currentStatus
            messageKind = status == .requiresApproval ? .requiresApproval : nil
        } catch {
            status = service.currentStatus
            messageKind = .updateFailed
        }
    }

    private var strings: LocalizedStrings {
        LocalizedStrings(language: languageStore.resolvedLanguage)
    }

    private enum MessageKind {
        case requiresApproval
        case updateFailed
    }
}

protocol LaunchAtLoginService {
    var currentStatus: AutoStartStatus { get }
    func register() throws
    func unregister() throws
}

struct MainAppLaunchAtLoginService: LaunchAtLoginService {
    var currentStatus: AutoStartStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled

        case .requiresApproval:
            return .requiresApproval

        case .notRegistered:
            return .disabled

        default:
            return .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
