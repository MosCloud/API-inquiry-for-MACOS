import Foundation

public struct LastRefreshTimeFormatter {
    private let locale: Locale
    private let timeZone: TimeZone
    private let strings: LocalizedStrings

    public init(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        language: ResolvedLanguage = .en
    ) {
        self.locale = locale
        self.timeZone = timeZone
        self.strings = LocalizedStrings(language: language)
    }

    public func withLanguage(_ language: ResolvedLanguage) -> LastRefreshTimeFormatter {
        LastRefreshTimeFormatter(locale: locale, timeZone: timeZone, language: language)
    }

    public func lastRefreshText(for date: Date?) -> String {
        guard let date else {
            return "\(strings.lastUpdatedPrefix)\(labelSeparator)--"
        }

        return "\(strings.lastUpdatedPrefix)\(labelSeparator)\(timeText(for: date))"
    }

    public func resetText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "\(strings.resetsPrefix)\(labelSeparator)\(timeText(for: date))"
    }

    public func resetDateText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "\(strings.resetsPrefix)\(labelSeparator)\(dateText(for: date))"
    }

    public func planNextResetText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "\(strings.planNextResetsPrefix)\(labelSeparator)\(timeText(for: date))"
    }

    private var labelSeparator: String {
        strings.language == .zh ? "：" : ": "
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }

    private func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM/dd"

        return formatter.string(from: date)
    }
}
