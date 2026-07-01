import SwiftUI

enum RefreshActionFeedback: Hashable {
    case idle
    case refreshing
    case success
    case failure

    func systemImageName(default defaultName: String) -> String {
        switch self {
        case .idle, .refreshing:
            return defaultName
        case .success:
            return "checkmark"
        case .failure:
            return "xmark"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .idle, .refreshing:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    var disablesInteraction: Bool {
        self != .idle
    }

    var isCompletion: Bool {
        self == .success || self == .failure
    }
}

enum RefreshFeedbackTiming {
    static let turnDuration = 0.8
    static let turnDurationNanoseconds: UInt64 = 800_000_000
    static let completionDurationNanoseconds: UInt64 = 900_000_000
}
