import APIInquiryCore
import Foundation

enum QuotaWindowKindTests {
    static func run(using harness: TestHarness) {
        harness.expectEqual(QuotaWindowKind(label: "5h"), .fiveHour, "5h resolves to five-hour window")
        harness.expectEqual(QuotaWindowKind(label: "Week"), .week, "Week resolves to week window")
        harness.expectEqual(QuotaWindowKind(label: "7d"), .week, "7d resolves to week window")
        harness.expectEqual(QuotaWindowKind(label: "Monthly"), nil, "unknown labels stay unknown")

        let zh = LocalizedStrings(language: .zh)
        let en = LocalizedStrings(language: .en)
        harness.expectEqual(zh.quotaWindowLabel(.fiveHour), "5 时", "chinese five-hour kind label")
        harness.expectEqual(zh.quotaWindowLabel(.week), "1 周", "chinese week kind label")
        harness.expectEqual(en.quotaWindowLabel(.week), "7d", "english week kind label")

        let quota = QuotaWindowSnapshot(
            label: "Week",
            kind: .week,
            remainingPercentage: Decimal(64),
            resetAt: nil,
            isAvailable: true
        )
        harness.expectEqual(quota.label, "Week", "quota keeps provider label")
        harness.expectEqual(quota.resolvedKind, .week, "quota exposes semantic kind")
    }
}
