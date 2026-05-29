import APIInquiryCore
import Foundation
import SwiftUI

enum ConsoleMetrics {
    static let providerHomepageButtonHeight: CGFloat = 40
    static let providerModuleHorizontalPadding: CGFloat = 14
    static let providerModuleVerticalPadding: CGFloat = 6
    static let providerModuleMinHeight: CGFloat = 116
    static let providerHeaderMetricsSpacing: CGFloat = 6
    static let homeProviderListSpacing: CGFloat = 10
    static let apiProviderListSpacing: CGFloat = 10
    static let apiProviderModuleVerticalPadding: CGFloat = 6
    static let apiProviderModuleMinHeight: CGFloat = 58
    static let providerRowCornerRadius: CGFloat = 8
    static let navigationHeight: CGFloat = 40
    static let navigationButtonHeight: CGFloat = 32
    static let navigationIconSize: CGFloat = 18
    static let sectionHeaderHeight: CGFloat = 28
    static let projectHomepageURL = URL(string: "https://github.com/MosCloud/API-inquiry-for-MACOS")!
}

enum ProviderToneColor {
    static func status(_ tone: ProviderStatusTone) -> Color {
        switch tone {
        case .success:
            return .green
        case .refreshing:
            return .blue
        case .warning:
            return .orange
        case .neutral:
            return .secondary
        }
    }

    static func amount(_ tone: ProviderAmountTone) -> Color {
        switch tone {
        case .neutral:
            return .secondary
        case .good:
            return .green
        case .warning:
            return Color(red: 1.0, green: 0.78, blue: 0.04)
        case .critical:
            return .red
        }
    }

    static func feedback(_ kind: SettingsFeedbackKind) -> Color {
        switch kind {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    static func apiAccess(isLoaded: Bool) -> Color {
        isLoaded ? .green : .secondary
    }
}
