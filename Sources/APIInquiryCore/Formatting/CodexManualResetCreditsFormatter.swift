import Foundation

public enum CodexManualResetCreditsDisplayState: Equatable {
    case idle
    case loading(previous: CodexManualResetCreditsSnapshot?)
    case loaded(CodexManualResetCreditsSnapshot)
    case failed(previous: CodexManualResetCreditsSnapshot?)
}

public enum CodexManualResetCreditsFormatter {
    public static func summaryText(
        for state: CodexManualResetCreditsDisplayState,
        now: Date,
        strings: LocalizedStrings,
        calendar: Calendar
    ) -> String {
        switch state {
        case .idle:
            return "--"
        case .loading(let previous):
            return previous.map { summaryText(for: $0, now: now, strings: strings, calendar: calendar) } ?? loadingText(strings)
        case .loaded(let snapshot):
            return summaryText(for: snapshot, now: now, strings: strings, calendar: calendar)
        case .failed(let previous):
            return previous.map { summaryText(for: $0, now: now, strings: strings, calendar: calendar) } ?? failedText(strings)
        }
    }

    private static func summaryText(
        for snapshot: CodexManualResetCreditsSnapshot,
        now: Date,
        strings: LocalizedStrings,
        calendar: Calendar
    ) -> String {
        let availableCredits = snapshot.credits.filter { credit in
            credit.redeemedAt == nil && (credit.expiresAt.map { $0 > now } ?? false)
        }

        let countText = countText(for: availableCredits.count, strings: strings)
        guard let nearestExpiry = availableCredits.compactMap(\.expiresAt).min() else {
            return countText
        }

        let month = calendar.component(.month, from: nearestExpiry)
        let day = calendar.component(.day, from: nearestExpiry)
        return "\(countText) · \(month)/\(day) \(expiresText(strings))"
    }

    private static func countText(for count: Int, strings: LocalizedStrings) -> String {
        switch strings.language {
        case .zh:
            return "\(count) 张"
        case .en:
            return "\(count)"
        }
    }

    private static func loadingText(_ strings: LocalizedStrings) -> String {
        strings.manualResetChecking
    }

    private static func failedText(_ strings: LocalizedStrings) -> String {
        strings.manualResetFailed
    }

    private static func expiresText(_ strings: LocalizedStrings) -> String {
        switch strings.language {
        case .zh:
            return "到期"
        case .en:
            return "expires"
        }
    }
}
