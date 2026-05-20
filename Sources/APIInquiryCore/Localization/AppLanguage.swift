import Foundation

public enum ResolvedLanguage: String, Equatable {
    case zh
    case en
}

public enum AppLanguage: String, CaseIterable, Equatable {
    case auto
    case zh
    case en

    public static let defaultValue: AppLanguage = .auto

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .zh:
            return .zh
        case .en:
            return .en
        case .auto:
            for preferredLanguage in preferredLanguages {
                let normalizedLanguage = preferredLanguage.lowercased()
                if normalizedLanguage.hasPrefix("zh") {
                    return .zh
                }
                if normalizedLanguage.hasPrefix("en") {
                    return .en
                }
            }
            return .en
        }
    }
}
