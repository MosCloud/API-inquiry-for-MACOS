import Foundation

public protocol ProviderPreferencesStore: AnyObject {
    var addedProviderIDs: [ProviderID] { get set }
    var primaryProviderID: ProviderID? { get set }
}

public final class InMemoryProviderPreferencesStore: ProviderPreferencesStore {
    public var addedProviderIDs: [ProviderID]
    public var primaryProviderID: ProviderID?

    public init(
        addedProviderIDs: [ProviderID] = [],
        primaryProviderID: ProviderID? = nil
    ) {
        self.addedProviderIDs = addedProviderIDs
        self.primaryProviderID = primaryProviderID
    }
}

public final class UserDefaultsProviderPreferencesStore: ProviderPreferencesStore {
    private let userDefaults: UserDefaults
    private let addedProviderIDsKey: String
    private let primaryProviderIDKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        namespace: String = "APIInquiry"
    ) {
        self.userDefaults = userDefaults
        self.addedProviderIDsKey = "\(namespace).addedProviderIDs"
        self.primaryProviderIDKey = "\(namespace).primaryProviderID"
    }

    public var addedProviderIDs: [ProviderID] {
        get {
            userDefaults.stringArray(forKey: addedProviderIDsKey)?
                .compactMap(ProviderID.init(rawValue:)) ?? []
        }
        set {
            userDefaults.set(newValue.map(\.rawValue), forKey: addedProviderIDsKey)
        }
    }

    public var primaryProviderID: ProviderID? {
        get {
            guard let rawValue = userDefaults.string(forKey: primaryProviderIDKey) else {
                return nil
            }
            return ProviderID(rawValue: rawValue)
        }
        set {
            userDefaults.set(newValue?.rawValue, forKey: primaryProviderIDKey)
        }
    }
}
