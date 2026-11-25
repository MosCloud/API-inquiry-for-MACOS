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
    /// Which kind of number `amountText` holds. The hero picks its layout from this rather
    /// than inferring it from `detailKind`, which cannot tell credits from a percentage
    /// (#123).
    public let displayMode: QuotaDisplayMode

    /// Whether the hero must drop to the smaller amount size.
    ///
    /// An explicit size step, not `minimumScaleFactor`: that shrinks text silently and hides
    /// the squeeze instead of exposing it. Six integer digits fit at 42 pt inside the 288 pt
    /// panel; seven do not once the unit suffix is on the line (#123).
    public var usesCompactAmountLayout: Bool {
        if amountText == "--" {
            return true
        }
        let integerDigits = amountText.prefix { $0 != "." }.filter(\.isNumber).count
        return integerDigits >= 7
    }
}

/// The same reset instant in two densities: `full` keeps the "Resets:" prefix for rows
/// with room, `short` drops it for the compact hero and grid columns.
public struct ResetLabel: Equatable {
    public let full: String
    public let short: String

    public init(full: String, short: String) {
        self.full = full
        self.short = short
    }
}

public struct ProviderDetailRow: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailText: String
    public let quotaWindowRows: [QuotaWindowDisplayRow]
    /// A balance provider has no windows, but it still uses the same three columns so the
    /// amount lines up with the quota percentages and the currency with the reset dates.
    public let balanceColumns: SecondaryRowColumns?
    public let statusText: String
    public let statusTone: ProviderStatusTone

    /// What the trailing cell should say out loud: the spelled-out sentence when there is
    /// one, otherwise the currency code, which is what a money row means.
    public func accessibilityTrailingText(for columns: SecondaryRowColumns) -> String {
        if let spelledOut = columns.trailingAccessibilityText {
            return spelledOut
        }
        return columns.currency
    }
}

public struct SecondaryRowColumns: Equatable {
    public let label: String
    public let amount: String
    public let currency: String
    /// What the trailing cell means, in words.
    ///
    /// A bare `06/30` beside a number reads as a fraction, and VoiceOver reads it as one
    /// too. The credit row's trailing cell therefore carries the date *and* this sentence
    /// for assistive tech, which is the condition the narrowed §5.2 rule depends on (#124).
    public let trailingAccessibilityText: String?

    public init(
        label: String,
        amount: String,
        currency: String,
        trailingAccessibilityText: String? = nil
    ) {
        self.label = label
        self.amount = amount
        self.currency = currency
        self.trailingAccessibilityText = trailingAccessibilityText
    }
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
    public let resetLabel: ResetLabel?
    public let isAvailable: Bool

    /// Convenience for the surfaces that need one of the two densities.
    public var resetText: String? { resetLabel?.full }
    public var resetShortText: String? { resetLabel?.short }
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
