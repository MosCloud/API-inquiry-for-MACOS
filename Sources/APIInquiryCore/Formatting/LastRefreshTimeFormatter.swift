import Foundation

public struct LastRefreshTimeFormatter {
    private let locale: Locale
    private let timeZone: TimeZone

    public init(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.locale = locale
        self.timeZone = timeZone
    }

    public func lastRefreshText(for date: Date?) -> String {
        guard let date else {
            return "Last updated: --"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return "Last updated: \(formatter.string(from: date))"
    }
}
