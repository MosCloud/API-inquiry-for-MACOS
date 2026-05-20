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
            return preferredLanguages.contains { preferredLanguage in
                preferredLanguage.lowercased().hasPrefix("zh")
            } ? .zh : .en
        }
    }
}

