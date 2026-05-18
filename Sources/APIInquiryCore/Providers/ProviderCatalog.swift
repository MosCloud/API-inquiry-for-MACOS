import Foundation

public struct ProviderDescriptor: Equatable {
    public let id: ProviderID
    public let displayName: String
    public let menuPrefix: String
    public let credentialAccount: String
    public let homepageURL: URL
    public let detailKind: ProviderDetailKind

    public init(
        id: ProviderID,
        displayName: String,
        menuPrefix: String,
        credentialAccount: String,
        homepageURL: URL,
        detailKind: ProviderDetailKind
    ) {
        self.id = id
        self.displayName = displayName
        self.menuPrefix = menuPrefix
        self.credentialAccount = credentialAccount
        self.homepageURL = homepageURL
        self.detailKind = detailKind
    }
}

public struct ProviderCatalog: Equatable {
    public let descriptors: [ProviderDescriptor]
    public let defaultProviderID: ProviderID

    public init(descriptors: [ProviderDescriptor], defaultProviderID: ProviderID) {
        self.descriptors = descriptors
        self.defaultProviderID = defaultProviderID
    }

    public func descriptor(for id: ProviderID) -> ProviderDescriptor? {
        descriptors.first { $0.id == id }
    }
}

public extension ProviderCatalog {
    static let `default` = ProviderCatalog(
        descriptors: [
            ProviderDescriptor(
                id: .deepseek,
                displayName: "DeepSeek",
                menuPrefix: "DS",
                credentialAccount: "deepseek-api-key",
                homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
                detailKind: .balance
            ),
            ProviderDescriptor(
                id: .zhipuCodingPlan,
                displayName: "Zhipu GLM Coding Plan",
                menuPrefix: "GLM",
                credentialAccount: "zhipu-coding-plan-api-key",
                homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
                detailKind: .planUsage
            )
        ],
        defaultProviderID: .deepseek
    )
}
