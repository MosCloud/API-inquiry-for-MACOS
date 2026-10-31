public struct PrimaryProviderDisplayParts: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailKind: ProviderDetailKind
    public let leadingText: String
    public let amountText: String
    public let amountValue: Double?
    public let amountTone: ProviderAmountTone
    public let trailingText: String
    public let captionText: String
}

public struct ProviderDetailRow: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailText: String
    public let quotaWindowRows: [QuotaWindowDisplayRow]
    public let statusText: String
    public let statusTone: ProviderStatusTone
    public let resetText: String?
    /// Same instant as `resetText`, without the "Resets:" prefix.
    public let resetShortText: String?
}

public struct QuotaWindowDisplayRow: Equatable {
    public let label: String
    /// Which quota window this row came from; the hero picks `.fiveHour` as its focus.
    public let kind: QuotaWindowKind?
    /// Shorter variant for the menu bar hero rows (English uses Week/Month).
    public let heroLabel: String
    public let amountText: String
    public let amountValue: Double?
    public let amountTone: ProviderAmountTone
    public let suffixText: String
    public let detailText: String
    public let resetText: String?
    /// Same instant as `resetText`, without the "Resets:" prefix.
    public let resetShortText: String?
    public let isAvailable: Bool
}

/// The hero's compressed second tier: every window except the focused one, on one line.
public struct QuotaWindowSummary: Equatable {
    /// `每周 95% · 每月 98%`
    public let text: String
    /// `11/02·11/30`, aligned with the focused row's reset time.
    public let resetText: String?

    public init(text: String, resetText: String?) {
        self.text = text
        self.resetText = resetText
    }
}

public enum ProviderStatusTone: Equatable {
    case neutral
    case success
    case refreshing
    case warning
}

public enum ProviderAmountTone: Equatable {
    case neutral
    case good
    case warning
    case critical
}
