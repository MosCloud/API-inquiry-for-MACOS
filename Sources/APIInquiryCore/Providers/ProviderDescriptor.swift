import Foundation

public enum ProviderCredentialManagement: Equatable {
    case appManagedAPIKey
    case localExternalConfiguration

    public var supportsConsoleCredentialManagement: Bool {
        self == .appManagedAPIKey
    }
}

public enum ProviderAccessPurpose: Equatable {
    case prepaidBalance
    case planQuota
}

public struct ProviderDescriptor: Equatable {
    public let id: ProviderID
    public let displayName: String
    public let menuPrefix: String
    public let credentialAccount: String
    public let homepageURL: URL
    public let detailKind: ProviderDetailKind
    public let credentialManagement: ProviderCredentialManagement
    public let accessPurpose: ProviderAccessPurpose
    public let menuTitlePrefix: String?
    public let secondaryDisplayName: String

    public init(
        id: ProviderID,
        displayName: String,
        menuPrefix: String,
        credentialAccount: String,
        homepageURL: URL,
        detailKind: ProviderDetailKind,
        credentialManagement: ProviderCredentialManagement,
        accessPurpose: ProviderAccessPurpose,
        menuTitlePrefix: String?,
        secondaryDisplayName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.menuPrefix = menuPrefix
        self.credentialAccount = credentialAccount
        self.homepageURL = homepageURL
        self.detailKind = detailKind
        self.credentialManagement = credentialManagement
        self.accessPurpose = accessPurpose
        self.menuTitlePrefix = menuTitlePrefix
        self.secondaryDisplayName = secondaryDisplayName ?? displayName
    }
}
