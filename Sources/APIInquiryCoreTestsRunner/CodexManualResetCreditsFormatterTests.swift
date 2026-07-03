import APIInquiryCore
import Foundation

enum CodexManualResetCreditsFormatterTests {
    static func run(using harness: TestHarness) {
        testChineseSummaryUsesNearestAvailableExpiry(using: harness)
        testSummaryUsesProvidedTimezone(using: harness)
        testDetailModelShowsAllCreditsInLocalTimezone(using: harness)
        testEmptyAvailableCreditsReturnsZero(using: harness)
        testIdleReturnsPlaceholder(using: harness)
        testLoadingReturnsChecking(using: harness)
        testLoadingWithPreviousReturnsPreviousSummary(using: harness)
        testFailedWithoutCacheReturnsFailure(using: harness)
        testFailedWithPreviousReturnsPreviousSummary(using: harness)
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

        harness.expectEqual(text, "2 张 · 07/18 到期", "manual reset zh summary")
    }

    private static func testSummaryUsesProvidedTimezone(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let snapshot = CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-07-18T00:35:47Z"), redeemedAt: nil)
            ],
            fetchedAt: now
        )
        let shanghaiText = CodexManualResetCreditsFormatter.summaryText(
            for: .loaded(snapshot),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: calendar(timeZoneIdentifier: "Asia/Shanghai")
        )
        let losAngelesText = CodexManualResetCreditsFormatter.summaryText(
            for: .loaded(snapshot),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: calendar(timeZoneIdentifier: "America/Los_Angeles")
        )

        harness.expectEqual(shanghaiText, "1 张 · 07/18 到期", "manual reset shanghai local summary")
        harness.expectEqual(losAngelesText, "1 张 · 07/17 到期", "manual reset los angeles local summary")
    }

    private static func testDetailModelShowsAllCreditsInLocalTimezone(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let snapshot = CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(
                    grantedAt: isoDate("2026-06-27T00:44:20Z"),
                    expiresAt: isoDate("2026-07-27T00:44:20Z"),
                    redeemedAt: now
                ),
                CodexManualResetCredit(
                    grantedAt: isoDate("2026-06-18T00:35:47Z"),
                    expiresAt: isoDate("2026-07-18T00:35:47Z"),
                    redeemedAt: nil
                )
            ],
            fetchedAt: now
        )
        let model = CodexManualResetCreditsFormatter.detailModel(
            for: .loaded(snapshot),
            strings: LocalizedStrings(language: .zh),
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        harness.expectEqual(model.title, "手动重置详情", "manual reset detail title")
        harness.expectEqual(model.grantedAtTitle, "发放时间", "manual reset granted title")
        harness.expectEqual(model.expiresAtTitle, "过期时间", "manual reset expires title")
        harness.expectEqual(model.rows.count, 2, "manual reset detail shows all credits")
        harness.expectEqual(
            model.rows.first?.grantedAtText,
            "2026-06-18 08:35:47 UTC+08:00",
            "manual reset detail first granted"
        )
        harness.expectEqual(
            model.rows.first?.expiresAtText,
            "2026-07-18 08:35:47 UTC+08:00",
            "manual reset detail first expires"
        )
        harness.expectEqual(
            model.rows.last?.expiresAtText,
            "2026-07-27 08:44:20 UTC+08:00",
            "manual reset detail second expires"
        )
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

    private static func testLoadingWithPreviousReturnsPreviousSummary(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .loading(previous: previousSnapshot(now: now)),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "1 张 · 07/18 到期", "manual reset loading keeps previous summary")
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

    private static func testFailedWithPreviousReturnsPreviousSummary(using harness: TestHarness) {
        let now = isoDate("2026-07-01T00:00:00Z")
        let text = CodexManualResetCreditsFormatter.summaryText(
            for: .failed(previous: previousSnapshot(now: now)),
            now: now,
            strings: LocalizedStrings(language: .zh),
            calendar: shanghaiCalendar()
        )

        harness.expectEqual(text, "1 张 · 07/18 到期", "manual reset failed keeps previous summary")
    }

    private static func previousSnapshot(now: Date) -> CodexManualResetCreditsSnapshot {
        CodexManualResetCreditsSnapshot(
            credits: [
                CodexManualResetCredit(grantedAt: now, expiresAt: isoDate("2026-07-18T00:35:47Z"), redeemedAt: nil)
            ],
            fetchedAt: now
        )
    }

    private static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private static func shanghaiCalendar() -> Calendar {
        calendar(timeZoneIdentifier: "Asia/Shanghai")
    }

    private static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}
