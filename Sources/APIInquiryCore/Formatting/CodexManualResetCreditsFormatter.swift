import Foundation

public enum CodexManualResetCreditsDisplayState: Equatable {
    case idle
    case loading(previous: CodexManualResetCreditsSnapshot?)
    case loaded(CodexManualResetCreditsSnapshot)
    case failed(previous: CodexManualResetCreditsSnapshot?)
}

public struct CodexManualResetCreditDisplayRow: Equatable, Identifiable {
    public let id: String
    public let grantedAtText: String
    public let expiresAtText: String

    public init(id: String, grantedAtText: String, expiresAtText: String) {
        self.id = id
        self.grantedAtText = grantedAtText
        self.expiresAtText = expiresAtText
    }
}

public struct CodexManualResetCreditsDetailModel: Equatable {
    public let title: String
    public let grantedAtTitle: String
    public let expiresAtTitle: String
    public let emptyText: String
    public let rows: [CodexManualResetCreditDisplayRow]

    public init(
        title: String,
        grantedAtTitle: String,
        expiresAtTitle: String,
        emptyText: String,
        rows: [CodexManualResetCreditDisplayRow]
    ) {
        self.title = title
        self.grantedAtTitle = grantedAtTitle
        self.expiresAtTitle = expiresAtTitle
        self.emptyText = emptyText
        self.rows = rows
    }
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
        return "\(countText) · \(summaryDateText(month: month, day: day)) \(expiresText(strings))"
    }

    private static func countText(for count: Int, strings: LocalizedStrings) -> String {
        switch strings.language {
        case .zh:
            return "\(count) 张"
        case .en:
            return "\(count)"
        }
    }

    private static func summaryDateText(month: Int, day: Int) -> String {
        String(format: "%02d/%02d", month, day)
    }

    public static func detailModel(
        for state: CodexManualResetCreditsDisplayState,
        strings: LocalizedStrings,
        timeZone: TimeZone
    ) -> CodexManualResetCreditsDetailModel {
        let snapshot = snapshot(for: state)
        let rows = snapshot?.credits
            .enumerated()
            .sorted { lhs, rhs in
                let lhsExpiry = lhs.element.expiresAt ?? Date.distantFuture
                let rhsExpiry = rhs.element.expiresAt ?? Date.distantFuture
                if lhsExpiry == rhsExpiry {
                    return lhs.offset < rhs.offset
                }
                return lhsExpiry < rhsExpiry
            }
            .map { index, credit in
                CodexManualResetCreditDisplayRow(
                    id: "\(index)-\(credit.grantedAt?.timeIntervalSince1970 ?? -1)-\(credit.expiresAt?.timeIntervalSince1970 ?? -1)-\(credit.redeemedAt?.timeIntervalSince1970 ?? -1)",
                    grantedAtText: fullDateText(for: credit.grantedAt, timeZone: timeZone),
                    expiresAtText: fullDateText(for: credit.expiresAt, timeZone: timeZone)
                )
            } ?? []

        return CodexManualResetCreditsDetailModel(
            title: strings.manualResetDetailsTitle,
            grantedAtTitle: strings.manualResetGrantedAtTitle,
            expiresAtTitle: strings.manualResetExpiresAtTitle,
            emptyText: strings.manualResetNoRecords,
            rows: rows
        )
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

    private static func snapshot(for state: CodexManualResetCreditsDisplayState) -> CodexManualResetCreditsSnapshot? {
        switch state {
        case .idle:
            return nil
        case .loading(let previous):
            return previous
        case .loaded(let snapshot):
            return snapshot
        case .failed(let previous):
            return previous
        }
    }

    private static func fullDateText(for date: Date?, timeZone: TimeZone) -> String {
        guard let date else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(formatter.string(from: date)) \(offsetText(for: timeZone.secondsFromGMT(for: date)))"
    }

    private static func offsetText(for secondsFromGMT: Int) -> String {
        let sign = secondsFromGMT >= 0 ? "+" : "-"
        let totalMinutes = abs(secondsFromGMT) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "UTC%@%02d:%02d", sign, hours, minutes)
    }
}
