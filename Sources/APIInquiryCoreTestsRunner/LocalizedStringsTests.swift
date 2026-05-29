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
        harness.expectEqual(strings.updatedMetricTitle, "更新于", "chinese updated metric title")
        harness.expectEqual(strings.deleteAPIKeyConfirmation, "删除已保存的 API 密钥？", "chinese delete api key confirmation")
        harness.expectEqual(strings.keychainName, "密钥串", "chinese keychain")
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
