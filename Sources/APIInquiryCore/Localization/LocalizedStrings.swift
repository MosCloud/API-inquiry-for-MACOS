import Foundation

public struct LocalizedStrings: Equatable {
    public let language: ResolvedLanguage

    public init(language: ResolvedLanguage) {
        self.language = language
    }

    public var languageTitle: String { text(en: "Language", zh: "语言") }
    public var followSystemLanguage: String { text(en: "Follow system language", zh: "跟随系统语言") }
    public var autoLanguage: String { text(en: "Auto", zh: "自动") }
    public var chineseLanguage: String { "中文" }
    public var englishLanguage: String { "English" }

    public var setup: String { text(en: "Setup", zh: "设置") }
    public var console: String { text(en: "Console", zh: "控制台") }
    public var openConsole: String { text(en: "Open Console", zh: "打开控制台") }
    public var refresh: String { text(en: "Refresh", zh: "刷新") }
    public var refreshing: String { text(en: "Refreshing", zh: "刷新中") }
    public var retry: String { text(en: "Retry", zh: "重试") }
    public var quit: String { text(en: "Quit", zh: "退出") }
    public var provider: String { text(en: "Provider", zh: "供应商") }

    public var notConfigured: String { text(en: "Not configured", zh: "未配置") }
    public var configured: String { text(en: "Configured", zh: "已配置") }
    public var loaded: String { text(en: "Loaded", zh: "已加载") }
    public var notLoaded: String { text(en: "Not loaded", zh: "未加载") }
    public var checking: String { text(en: "Checking", zh: "检查中") }
    public var active: String { text(en: "Active", zh: "正常") }
    public var available: String { text(en: "Available", zh: "可用") }
    public var balanceInsufficient: String { text(en: "Balance insufficient", zh: "余额不足") }
    public var insufficientBalance: String { text(en: "Insufficient balance", zh: "余额不足") }
    public var balanceSufficient: String { text(en: "Balance Sufficient", zh: "余额充足") }
    public var balanceLow: String { text(en: "Balance Low", zh: "余额偏低") }
    public var balanceCritical: String { text(en: "Balance Critical", zh: "余额告急") }
    public var planAvailable: String { text(en: "Plan available", zh: "计划可用") }
    public var limitReached: String { text(en: "Limit reached", zh: "已达上限") }
    public var planExpired: String { text(en: "Plan expired", zh: "计划已过期") }
    public var quotaAvailable: String { text(en: "Quota available", zh: "额度可用") }
    public var quotaExhausted: String { text(en: "Quota exhausted", zh: "额度已用尽") }
    public var quotaSufficient: String { text(en: "Quota Sufficient", zh: "额度充足") }
    public var quotaLow: String { text(en: "Quota Low", zh: "额度偏低") }
    public var quotaCritical: String { text(en: "Quota Critical", zh: "额度告急") }
    public var invalid: String { text(en: "Invalid", zh: "无效") }
    public var unavailable: String { text(en: "Unavailable", zh: "不可用") }
    public var unknown: String { text(en: "Unknown", zh: "未知") }

    public var lastUpdatedPrefix: String { text(en: "Last updated", zh: "最近更新") }
    public var resetsPrefix: String { text(en: "Resets", zh: "重置于") }
    public var planNextResetsPrefix: String { text(en: "Plan Next Resets", zh: "计划下次重置") }
    public var usedSuffix: String { text(en: "used", zh: "已用") }
    public var remainingSuffix: String { text(en: "remaining", zh: "剩余") }
    public var compactRemainingSuffix: String { text(en: "remg", zh: "剩余") }

    public var homeSection: String { text(en: "Home", zh: "首页") }
    public var apiSection: String { "API" }
    public var settingsSection: String { text(en: "Settings", zh: "设置") }
    public var versionTitle: String { text(en: "Version", zh: "版本") }
    public var projectHomepage: String { text(en: "Project Homepage", zh: "项目主页") }
    public var providersTitle: String { text(en: "Providers", zh: "供应商") }
    public var addProvider: String { text(en: "Add Provider", zh: "添加供应商") }
    public var apiProvidersTitle: String { text(en: "API Providers", zh: "API 供应商") }
    public var menuBar: String { text(en: "Menu Bar", zh: "菜单栏") }
    public var showInMenuBar: String { text(en: "Show in Menu Bar", zh: "显示在菜单栏") }

    public var apiKeyMetricTitle: String { text(en: "API Key", zh: "API 密钥") }
    public var statusMetricTitle: String { text(en: "Status", zh: "状态") }
    public var detailMetricTitle: String { text(en: "Detail", zh: "详情") }
    public var planMetricTitle: String { text(en: "Plan", zh: "计划") }
    public var manualResetMetricTitle: String { text(en: "Manual Reset", zh: "手动重置") }
    public var updatedMetricTitle: String { text(en: "Updated", zh: "更新于") }
    public var planNextResetsMetricTitle: String { text(en: "Plan Next Resets", zh: "计划下次重置") }
    public var refreshManualResetCredits: String {
        text(en: "Refresh manual reset credits", zh: "刷新手动重置信息")
    }
    public var manualResetChecking: String { text(en: "Checking", zh: "查询中") }
    public var manualResetFailed: String { text(en: "Failed", zh: "查询失败") }

    public var apiKeyPlaceholder: String { text(en: "API key", zh: "API 密钥") }
    public var newAPIKeyPlaceholder: String { text(en: "New API key", zh: "新 API 密钥") }
    public var save: String { text(en: "Save", zh: "保存") }
    public var saveReplacement: String { text(en: "Save Replacement", zh: "保存新密钥") }
    public var configureKey: String { text(en: "Configure Key", zh: "配置密钥") }
    public var replaceKey: String { text(en: "Replace Key", zh: "更换密钥") }
    public var deleteKey: String { text(en: "Delete Key", zh: "删除 API 密钥") }
    public var cancel: String { text(en: "Cancel", zh: "取消") }
    public var delete: String { text(en: "Delete", zh: "删除") }
    public var remove: String { text(en: "Remove", zh: "移除") }
    public var removeProvider: String { text(en: "Remove Provider", zh: "移除供应商") }
    public var moreActions: String { text(en: "More Actions", zh: "更多操作") }
    public var currentStatus: String { text(en: "Current Status", zh: "当前状态") }
    public var quotaWindow: String { text(en: "Quota Window", zh: "额度窗口") }
    public var prepaidBalanceCheckPurpose: String {
        text(en: "Available for prepaid balance checks", zh: "可用于充值余额查询")
    }
    public var planBalanceCheckPurpose: String {
        text(en: "Available for plan balance checks", zh: "可用于套餐余额查询")
    }
    public var openConfig: String { text(en: "Open Config", zh: "打开配置") }
    public var showConfigInFinder: String { text(en: "Show Config in Finder", zh: "在 Finder 中显示配置") }
    public var configCouldNotBeOpened: String { text(en: "Config could not be opened.", zh: "无法打开配置。") }

    public var removeProviderConfirmation: String {
        text(en: "Remove this provider?", zh: "移除此供应商？")
    }

    public var removeProviderAndDeleteAPIKeyConfirmation: String {
        text(
            en: "Remove this provider and delete its saved API key?",
            zh: "移除此供应商并删除已保存的 API 密钥？"
        )
    }

    public var deleteAPIKeyConfirmation: String {
        text(en: "Delete the saved API key?", zh: "删除已保存的 API 密钥？")
    }

    public var savedSecurely: String { text(en: "Saved securely.", zh: "已安全保存。") }
    public var apiKeyDeleted: String { text(en: "API key deleted.", zh: "API 密钥已删除。") }
    public var apiKeyRequired: String { text(en: "API key is required.", zh: "请输入 API 密钥。") }
    public var apiKeyCouldNotBeSaved: String { text(en: "API key could not be saved.", zh: "无法保存 API 密钥。") }
    public var apiKeyCouldNotBeDeleted: String { text(en: "API key could not be deleted.", zh: "无法删除 API 密钥。") }
    public var providerCouldNotBeRemoved: String { text(en: "Provider could not be removed.", zh: "无法移除供应商。") }

    public var apiKeySavedButRefreshFailed: String {
        text(
            en: "API key saved, but refresh failed. API key may be invalid. Replace or delete it in the console.",
            zh: "API 密钥已保存，但刷新失败。API 密钥可能无效，请在控制台中更换或删除。"
        )
    }

    public var invalidBalanceAPIURL: String { text(en: "Balance API URL is invalid.", zh: "Balance API URL 无效。") }

    public var apiKeyMayBeInvalid: String {
        text(
            en: "API key may be invalid. Replace or delete it in the console.",
            zh: "API 密钥可能无效，请在控制台中更换或删除。"
        )
    }

    public var balanceAPIRateLimitReached: String {
        text(en: "Balance API rate limit reached. Try again shortly.", zh: "Balance API 已达到频率限制，请稍后重试。")
    }

    public func balanceAPIReturnedHTTP(_ statusCode: Int) -> String {
        text(
            en: "Balance API returned HTTP \(statusCode). Try again shortly.",
            zh: "Balance API 返回 HTTP \(statusCode)，请稍后重试。"
        )
    }

    public var balanceAPIMissingBalanceInfo: String {
        text(en: "Balance API did not return balance information.", zh: "Balance API 未返回余额信息。")
    }

    public var invalidBalanceAmount: String {
        text(en: "Balance API returned an invalid balance amount.", zh: "Balance API 返回的余额金额无效。")
    }

    public var unsupportedResponseKind: String {
        text(en: "Provider returned an unsupported response kind.", zh: "供应商返回了不支持的响应类型。")
    }

    public var planUsageLimitReached: String {
        text(en: "Plan usage limit reached. Wait for the next reset.", zh: "计划用量已达上限，请等待下次重置。")
    }

    public var planHasExpired: String {
        text(en: "Plan has expired. Renew it in the provider console.", zh: "计划已过期，请在供应商控制台续订。")
    }

    public var balanceAPIResponseCouldNotBeDecoded: String {
        text(en: "Balance API response could not be decoded.", zh: "无法解析 Balance API 响应。")
    }

    public var refreshFailed: String {
        text(en: "Refresh failed. Try again shortly.", zh: "刷新失败，请稍后重试。")
    }

    public var invalidServerResponse: String {
        text(en: "The server response was invalid.", zh: "服务器响应无效。")
    }

    public var credentialDataCodingFailed: String {
        text(en: "Credential data could not be encoded or decoded.", zh: "凭证数据无法编码或解码。")
    }

    public var appConsoleTitle: String { text(en: "API Inquiry Console", zh: "API Inquiry 控制台") }
    public var autoStart: String { text(en: "AutoStart", zh: "开机自启") }

    public var approveAutoStartInSystemSettings: String {
        text(en: "Approve AutoStart in System Settings.", zh: "请在系统设置中允许开机自启。")
    }

    public var autoStartCouldNotBeUpdated: String {
        text(en: "AutoStart could not be updated.", zh: "无法更新开机自启设置。")
    }

    public var keychainName: String { text(en: "Keychain", zh: "密钥串") }

    public func keychainUnexpectedStatus(_ status: Int32) -> String {
        text(en: "Keychain returned unexpected status \(status).", zh: "密钥串返回了异常状态 \(status)。")
    }

    public func openProviderAPIPage(_ providerDisplayName: String) -> String {
        text(en: "Open \(providerDisplayName) API page", zh: "打开 \(providerDisplayName) API 页面")
    }

    public var setupGuidanceTemplate: String {
        text(
            en: "Add a {Provider} API key to start checking your balance.",
            zh: "添加 {供应商} API 密钥以开始查询余额。"
        )
    }

    public func setupGuidance(providerDisplayName: String) -> String {
        text(
            en: "Add a \(providerDisplayName) API key to start checking your balance.",
            zh: "添加 \(providerDisplayName) API 密钥以开始查询余额。"
        )
    }

    public func providerDisplayName(_ displayName: String) -> String {
        displayName
    }

    public func quotaWindowLabel(_ label: String) -> String {
        switch (language, label) {
        case (.zh, "5h"):
            return "5 时"
        case (.zh, "Week"), (.zh, "7d"):
            return "1 周"
        case (.en, "Week"):
            return "7d"
        default:
            return label
        }
    }

    public func languageOptionTitle(_ language: AppLanguage) -> String {
        switch language {
        case .auto:
            return autoLanguage
        case .zh:
            return chineseLanguage
        case .en:
            return englishLanguage
        }
    }

    private func text(en: String, zh: String) -> String {
        language == .zh ? zh : en
    }
}
