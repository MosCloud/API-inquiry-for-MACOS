import APIInquiryCore
import AppKit
import Foundation
import SwiftUI

enum ConsoleMetrics {
    static let windowWidth: CGFloat = 780
    static let windowHeight: CGFloat = 560
    static let windowMinWidth: CGFloat = 780
    static let windowMinHeight: CGFloat = 560
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
    private static let warningAmber = Color(red: 0.94, green: 0.62, blue: 0.12)

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
            return warningAmber
        case .critical:
            return .red
        }
    }

    static func menuAmount(_ tone: ProviderAmountTone) -> Color {
        switch tone {
        case .neutral:
            return .primary
        case .good:
            return .green
        case .warning:
            return warningAmber
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

    static func apiAccess(_ state: APIAccessState) -> Color {
        switch state {
        case .available:
            return .green
        case .unavailable:
            return .secondary
        }
    }
}

enum ConsoleSurfaceColor {
    static var separator: Color { Color(nsColor: .separatorColor) }
    static var subtleStroke: Color { Color(nsColor: .separatorColor).opacity(0.70) }
    static var selectedStroke: Color { Color.accentColor.opacity(0.65) }
    static var subtleFill: Color { Color.secondary.opacity(0.10) }
}
