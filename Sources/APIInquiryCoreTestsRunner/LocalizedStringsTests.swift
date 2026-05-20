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
    }

    private static func testEnglishStringsMatchExistingCopy(using harness: TestHarness) {
        let strings = LocalizedStrings(language: .en)

        harness.expectEqual(strings.notConfigured, "Not configured", "english not configured")
        harness.expectEqual(strings.refreshing, "Refreshing", "english refreshing")
        harness.expectEqual(strings.available, "Available", "english available")
        harness.expectEqual(strings.lastUpdatedPrefix, "Last updated", "english last updated")
        harness.expectEqual(strings.resetsPrefix, "Resets", "english resets")
        harness.expectEqual(strings.planNextResetsPrefix, "Plan Next Resets", "english plan next resets")
        harness.expectEqual(strings.apiKeyMetricTitle, "API Key", "english api key metric")
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
        harness.expectEqual(strings.apiKeyMetricTitle, "API 密钥", "chinese api key")
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
            "从密钥串删除已保存的 API 密钥？",
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
}
