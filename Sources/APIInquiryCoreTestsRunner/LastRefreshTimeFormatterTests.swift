import APIInquiryCore
import Foundation

enum LastRefreshTimeFormatterTests {
    static func run(using harness: TestHarness) {
        testUsesTwelveHourLocale(using: harness)
        testUsesTwentyFourHourLocale(using: harness)
        testResetUsesTwelveHourLocale(using: harness)
        testResetUsesTwentyFourHourLocale(using: harness)
        testResetDateUsesMonthDay(using: harness)
        testPlanNextResetUsesTwentyFourHourLocale(using: harness)
        testPlanNextResetHidesMissingDate(using: harness)
    }

    private static func testUsesTwelveHourLocale(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let text = formatter.lastRefreshText(for: sampleDate)

        harness.expectTrue(text.hasPrefix("Last updated: 11:05"), "twelve hour last refresh prefix")
        harness.expectTrue(text.contains("PM"), "twelve hour last refresh period")
    }

    private static func testUsesTwentyFourHourLocale(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        harness.expectEqual(formatter.lastRefreshText(for: sampleDate), "Last updated: 23:05", "twenty four hour last refresh")
    }

    private static func testResetUsesTwelveHourLocale(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let text = formatter.resetText(for: sampleDate)

        harness.expectTrue(text?.hasPrefix("Resets: 11:05") == true, "twelve hour reset prefix")
        harness.expectTrue(text?.contains("PM") == true, "twelve hour reset period")
    }

    private static func testResetUsesTwentyFourHourLocale(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        harness.expectEqual(formatter.resetText(for: sampleDate), "Resets: 23:05", "twenty four hour reset")
    }

    private static func testResetDateUsesMonthDay(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        harness.expectEqual(formatter.resetDateText(for: sampleDate), "Resets: 05/15", "reset date")
    }

    private static func testPlanNextResetUsesTwentyFourHourLocale(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        harness.expectEqual(formatter.planNextResetText(for: sampleDate), "Plan Next Resets: 23:05", "twenty four hour plan next reset")
    }

    private static func testPlanNextResetHidesMissingDate(using harness: TestHarness) {
        let formatter = LastRefreshTimeFormatter(
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        harness.expectEqual(formatter.planNextResetText(for: nil), nil as String?, "missing plan next reset")
    }

    private static var sampleDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 23
        components.minute = 5
        return components.date!
    }
}
