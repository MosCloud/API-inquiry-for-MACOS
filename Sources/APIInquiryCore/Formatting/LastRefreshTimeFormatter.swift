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

        return "Last updated: \(timeText(for: date))"
    }

    public func resetText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "Resets: \(timeText(for: date))"
    }

    public func resetDateText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "Resets: \(dateText(for: date))"
    }

    public func planNextResetText(for date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return "Plan Next Resets: \(timeText(for: date))"
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
