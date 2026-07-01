import APIInquiryCore
import Foundation

enum CodexManualResetCreditsFormatterTests {
    static func run(using harness: TestHarness) {
        testChineseSummaryUsesNearestAvailableExpiry(using: harness)
        testEmptyAvailableCreditsReturnsZero(using: harness)
        testIdleReturnsPlaceholder(using: harness)
        testLoadingReturnsChecking(using: harness)
        testFailedWithoutCacheReturnsFailure(using: harness)
    }

    private static func testChineseSummaryUsesNearestAvailableExpiry(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let snapshot = CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-07-18T00:35:47Z"), redeemedAt: nil),
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-07-27T00:44:20Z"), redeemedAt: nil)
            ],
            fetchedAt: now
        )
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .loaded(snapshot),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "2 张 · 7/18 到期", "manual reset zh summary")
    }

    private static func testEmptyAvailableCreditsReturnsZero(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let snapshot = CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-06-30T00:00:00Z"), redeemedAt: nil),
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-07-10T00:00:00Z"), redeemedAt: now)
            ],
            fetchedAt: now
        )
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .loaded(snapshot),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "0 张", "manual reset zero credits")
    }

    private static func testIdleReturnsPlaceholder(using harness: TestHarness) {
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .idle,
            now: Date(timeIntervalSince1970: 0),
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "--", "manual reset idle placeholder")
    }

    private static func testLoadingReturnsChecking(using harness: TestHarness) {
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .loading(previous: nil),
            now: Date(timeIntervalSince1970: 0),
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "查询中", "manual reset loading text")
    }

    private static func testFailedWithoutCacheReturnsFailure(using harness: TestHarness) {
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .failed(previous: nil),
            now: Date(timeIntervalSince1970: 0),
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "查询失败", "manual reset failed text")
    }

    private static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private static func shanghaiCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
}
