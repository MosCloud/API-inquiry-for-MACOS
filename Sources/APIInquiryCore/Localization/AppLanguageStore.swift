import Combine
import Foundation

public final class AppLanguageStore: ObservableObject {
    public static let defaultStorageKey = "APIInquiry.appLanguage"

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let preferredLanguages: () -> [String]

    @Published public var selection: AppLanguage {
        didSet {
            userDefaults.set(selection.rawValue, forKey: storageKey)
        }
    }

    public var resolvedLanguage: ResolvedLanguage {
        selection.resolved(preferredLanguages: preferredLanguages())
    }

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = AppLanguageStore.defaultStorageKey,
        preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.preferredLanguages = preferredLanguages

        if let rawValue = userDefaults.string(forKey: storageKey),
           let language = AppLanguage(rawValue: rawValue) {
            self.selection = language
        } else {
            self.selection = AppLanguage.defaultValue
        }
    }
}

