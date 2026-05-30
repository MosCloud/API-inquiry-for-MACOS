import Foundation

public struct BuiltInProviderRegistry {
    public let registrations: [ProviderRegistration]
    public let defaultProviderID: ProviderID

    public init(registrations: [ProviderRegistration], defaultProviderID: ProviderID) {
        self.registrations = registrations
        self.defaultProviderID = defaultProviderID
    }
}

public extension BuiltInProviderRegistry {
    static let `default` = BuiltInProviderRegistry(
        registrations: [
            ProviderRegistration(
                descriptor: ProviderDescriptor(
                    id: .deepseek,
                    displayName: "DeepSeek",
                    menuPrefix: "DS",
                    credentialAccount: "deepseek-api-key",
                    homepageURL: URL(string: "https://platform.deepseek.com/usage")!,
                    detailKind: .balance,
                    credentialManagement: .appManagedAPIKey,
                    accessPurpose: .prepaidBalance,
                    menuTitlePrefix: "DS"
                ),
                makeProvider: { DeepSeekBalanceProvider() }
            ),
            ProviderRegistration(
                descriptor: ProviderDescriptor(
                    id: .zhipuCodingPlan,
                    displayName: "Zhipu GLM Coding Plan",
                    menuPrefix: "GLM",
                    credentialAccount: "zhipu-coding-plan-api-key",
                    homepageURL: URL(string: "https://bigmodel.cn/claude-code")!,
                    detailKind: .planUsage,
                    credentialManagement: .appManagedAPIKey,
                    accessPurpose: .planQuota,
                    menuTitlePrefix: "GLM"
                ),
                makeProvider: { ZhipuCodingPlanProvider() }
            ),
            ProviderRegistration(
                descriptor: ProviderDescriptor(
                    id: .codex,
                    displayName: "Codex",
                    menuPrefix: "GPT",
                    credentialAccount: "codex-session-token",
                    homepageURL: URL(string: "https://chatgpt.com/codex/settings/usage")!,
                    detailKind: .quotaUsage,
                    credentialManagement: .localExternalConfiguration,
                    accessPurpose: .planQuota,
                    menuTitlePrefix: nil,
                    secondaryDisplayName: "OpenAI"
                ),
                makeProvider: { CodexQuotaProvider() }
            )
        ],
        defaultProviderID: .deepseek
    )
}
