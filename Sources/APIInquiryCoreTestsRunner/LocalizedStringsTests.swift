import APIInquiryCore
import Foundation

enum LocalizedStringsTests {
    static func run(using harness: TestHarness) {
        testEnglishStringsMatchExistingCopy(using: harness)
        testChineseStringsUseReviewedTerminology(using: harness)
        testProviderNamesRemainUntranslated(using: harness)
        testChineseQuotaWindowLabelsUseCompactText(using: harness)
        testChineseProviderGuidanceUsesLocalizedPlaceholder(using: harness)
        testErrorMessagesUseChineseTerminology(using: harness)
        testLocalizedErrorMessages(using: harness)
    }

    private static func testEnglishStringsMatchExistingCopy(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .en)

        harness.expectEqual(strings.notConfigured, "Not configured", "english not configured")
        harness.expectEqual(strings.refreshing, "Refreshing", "english refreshing")
        harness.expectEqual(strings.available, "Available", "english available")
        harness.expectEqual(strings.lastUpdatedPrefix, "Last updated", "english last updated")
        harness.expectEqual(strings.resetsPrefix, "Resets", "english resets")
        harness.expectEqual(strings.planNextResetsPrefix, "Plan Next Resets", "english plan next resets")
        harness.expectEqual(strings.settingsSection, "Settings", "english settings section")
        harness.expectEqual(strings.versionTitle, "Version", "english version title")
        harness.expectEqual(strings.projectHomepage, "Project Homepage", "english project homepage")
        harness.expectEqual(strings.apiKeyMetricTitle, "API Key", "english api key metric")
        harness.expectEqual(strings.deleteAPIKeyConfirmation, "Delete the saved API key?", "english delete api key confirmation")
        harness.expectEqual(strings.keychainName, "Keychain", "english keychain")
        harness.expectEqual(strings.moreActions, "More Actions", "english more actions")
        harness.expectEqual(strings.currentStatus, "Current Status", "english current status")
        harness.expectEqual(strings.quotaWindow, "Quota Window", "english quota window")
        harness.expectEqual(strings.manualResetMetricTitle, "Manual Reset", "english manual reset title")
        harness.expectEqual(strings.refreshManualResetCredits, "Refresh manual reset credits", "english manual reset refresh")
        harness.expectEqual(strings.manualResetChecking, "Checking", "english manual reset checking")
        harness.expectEqual(strings.manualResetFailed, "Failed", "english manual reset failed")
        harness.expectEqual(strings.manualResetDetailsTitle, "Manual Reset Details", "english manual reset detail title")
        harness.expectEqual(strings.showManualResetDetails, "Show manual reset details", "english show manual reset detail")
        harness.expectEqual(strings.manualResetGrantedAtTitle, "Granted at", "english manual reset granted")
        harness.expectEqual(strings.manualResetExpiresAtTitle, "Expires at", "english manual reset expires")
        harness.expectEqual(strings.manualResetNoRecords, "No manual reset records", "english manual reset empty")
        harness.expectEqual(strings.close, "Close", "english close")
    }

    private static func testChineseStringsUseReviewedTerminology(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(strings.notConfigured, "未配置", "chinese not configured")
        harness.expectEqual(strings.configured, "已配置", "chinese configured")
        harness.expectEqual(strings.refreshing, "刷新中", "chinese refreshing")
        harness.expectEqual(strings.checking, "检查中", "chinese checking")
        harness.expectEqual(strings.available, "可用", "chinese available")
        harness.expectEqual(strings.lastUpdatedPrefix, "最近更新", "chinese last updated")
        harness.expectEqual(strings.resetsPrefix, "重置于", "chinese resets")
        harness.expectEqual(strings.planNextResetsPrefix, "计划下次重置", "chinese plan next resets")
        harness.expectEqual(strings.settingsSection, "设置", "chinese settings section")
        harness.expectEqual(strings.versionTitle, "版本", "chinese version title")
        harness.expectEqual(strings.projectHomepage, "项目主页", "chinese project homepage")
        harness.expectEqual(strings.apiKeyMetricTitle, "API 密钥", "chinese api key")
        harness.expectEqual(strings.replaceKey, "更换密钥", "chinese replace key")
        harness.expectEqual(strings.deleteAPIKeyConfirmation, "删除已保存的 API 密钥？", "chinese delete api key confirmation")
        harness.expectEqual(strings.keychainName, "密钥串", "chinese keychain")
        harness.expectEqual(strings.moreActions, "更多操作", "chinese more actions")
        harness.expectEqual(strings.currentStatus, "当前状态", "chinese current status")
        harness.expectEqual(strings.quotaWindow, "额度窗口", "chinese quota window")
        harness.expectEqual(strings.manualResetMetricTitle, "手动重置", "chinese manual reset title")
        harness.expectEqual(strings.refreshManualResetCredits, "刷新手动重置信息", "chinese manual reset refresh")
        harness.expectEqual(strings.manualResetChecking, "查询中", "chinese manual reset checking")
        harness.expectEqual(strings.manualResetFailed, "查询失败", "chinese manual reset failed")
        harness.expectEqual(strings.manualResetDetailsTitle, "手动重置详情", "chinese manual reset detail title")
        harness.expectEqual(strings.showManualResetDetails, "查看手动重置详情", "chinese show manual reset detail")
        harness.expectEqual(strings.manualResetGrantedAtTitle, "发放时间", "chinese manual reset granted")
        harness.expectEqual(strings.manualResetExpiresAtTitle, "过期时间", "chinese manual reset expires")
        harness.expectEqual(strings.manualResetNoRecords, "暂无手动重置记录", "chinese manual reset empty")
        harness.expectEqual(strings.close, "关闭", "chinese close")
    }

    private static func testProviderNamesRemainUntranslated(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(strings.providerDisplayName("OpenAI"), "OpenAI", "OpenAI remains unchanged")
        harness.expectEqual(strings.providerDisplayName("DeepSeek"), "DeepSeek", "DeepSeek remains unchanged")
        harness.expectEqual(strings.providerDisplayName("Zhipu GLM Coding Plan"), "Zhipu GLM Coding Plan", "Zhipu remains unchanged")
    }

    private static func testChineseQuotaWindowLabelsUseCompactText(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(strings.quotaWindowLabel("5h"), "5 时", "chinese 5h compact label")
        harness.expectEqual(strings.quotaWindowLabel("Week"), "1 周", "chinese week compact label")
        harness.expectEqual(strings.quotaWindowLabel("7d"), "1 周", "chinese 7d compact label")
    }

    private static func testChineseProviderGuidanceUsesLocalizedPlaceholder(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(
            strings.setupGuidance(providerDisplayName: "DeepSeek"),
            "添加 DeepSeek API 密钥以开始查询余额。",
            "chinese setup guidance"
        )
        harness.expectEqual(
            strings.setupGuidanceTemplate,
            "添加 {供应商} API 密钥以开始查询余额。",
            "chinese setup guidance template"
        )
    }

    private static func testErrorMessagesUseChineseTerminology(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(
            strings.deleteAPIKeyConfirmation,
            "删除已保存的 API 密钥？",
            "chinese delete api key confirmation"
        )
        harness.expectEqual(
            strings.apiKeySavedButRefreshFailed,
            "API 密钥已保存，但刷新失败。API 密钥可能无效，请在控制台中更换或删除。",
            "chinese saved but refresh failed"
        )
        harness.expectEqual(
            strings.keychainUnexpectedStatus(42),
            "密钥串返回了异常状态 42。",
            "chinese keychain error"
        )
    }

    private static func testLocalizedErrorMessages(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .zh)

        harness.expectEqual(
            BalanceProviderError.authenticationFailed.localizedDescription(strings: strings),
            "API 密钥可能无效，请在控制台中更换或删除。",
            "chinese auth error"
        )
        harness.expectEqual(
            BalanceProviderError.serverError(statusCode: 503).localizedDescription(strings: strings),
            "Balance API 返回 HTTP 503，请稍后重试。",
            "chinese server error"
        )
        harness.expectEqual(
            CredentialStoreError.invalidCredentialData.localizedDescription(strings: strings),
            "凭证数据无法编码或解码。",
            "chinese credential data error"
        )
        harness.expectEqual(
            HTTPClientError.invalidResponse.localizedDescription(strings: strings),
            "服务器响应无效。",
            "chinese http response error"
        )
    }
}
