import APIInquiryCore
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: AutoStartStatus
    @Published private(set) var message: String?

    private let service: LaunchAtLoginService

    init(service: LaunchAtLoginService = MainAppLaunchAtLoginService()) {
        self.service = service
        self.status = service.currentStatus
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func refreshStatus() {
        status = service.currentStatus
        if status != .requiresApproval {
            message = nil
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
            message = status == .requiresApproval ? "Approve AutoStart in System Settings." : nil
        } catch {
            status = service.currentStatus
            message = "AutoStart could not be updated."
        }
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
