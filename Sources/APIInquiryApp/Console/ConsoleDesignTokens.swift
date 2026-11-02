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

    /// Room reserved on the trailing edge of the Console's scrolling lists so the
    /// scroller never draws on top of a card (#114). macOS draws both overlay and
    /// legacy scrollers inside the scroll view's bounds, so the content has to step
    /// aside; the width comes from the system instead of a guessed constant, because
    /// it changes with the scroll-bar setting and accessibility sizes.
    static var scrollerGutter: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)
    }
}

/// App-wide semantic palette. The file sits next to the Console metrics, but the
/// menu bar uses the same warning/error tokens.
enum ProviderToneColor {
    static let warning = Color.orange
    static let error = Color.red

    static func status(_ tone: ProviderStatusTone) -> Color {
        switch tone {
        case .success:
            return .green
        case .refreshing:
            return .blue
        case .warning:
            return warning
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
            return warning
        case .critical:
            return error
        }
    }

    static func menuAmount(_ tone: ProviderAmountTone) -> Color {
        switch tone {
        case .neutral:
            return .primary
        case .good:
            return .green
        case .warning:
            return warning
        case .critical:
            return error
        }
    }

    static func feedback(_ kind: SettingsFeedbackKind) -> Color {
        switch kind {
        case .success:
            return .green
        case .warning:
            return warning
        case .error:
            return error
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
