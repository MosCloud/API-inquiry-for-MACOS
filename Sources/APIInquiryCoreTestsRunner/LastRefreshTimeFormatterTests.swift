import APIInquiryCore
import Foundation

enum LastRefreshTimeFormatterTests {
    static func run(using harness: TestHarness) {
        testUsesTwelveHourLocale(using: harness)
        testUsesTwentyFourHourLocale(using: harness)
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
