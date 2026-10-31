import Foundation

public enum ProviderValueFormatter {
    public static func menuValueText(
        for state: BalanceState,
        isCredentialConfigured: Bool,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        if case .notConfigured = state {
            return isCredentialConfigured ? "--" : strings.setup
        }

        guard let snapshot = state.lastSnapshot else {
            return "--"
        }

        return ProviderSnapshotPresentation.make(from: snapshot, strings: strings).menuValueText
    }

    public static func detailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let snapshot else {
            return "--"
        }
        return ProviderSnapshotPresentation.make(from: snapshot, strings: strings).detailText
    }

    public static func consoleDetailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let snapshot else {
            return "--"
        }
        return ProviderSnapshotPresentation.make(from: snapshot, strings: strings).consoleDetailText
    }

    public static func creditsBalanceText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard case .quotaUsage(let usage) = snapshot,
              let credits = usage.credits else {
            return "--"
        }

        switch credits {
        case .balance(let balance):
            guard balance >= 0 else {
                return "--"
            }
            return "\(formatCredits(balance)) Credits"
        case .unlimited:
            return strings.creditsUnlimited
        }
    }

    public static func primaryDisplayParts(
        descriptor: ProviderDescriptor,
        state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> PrimaryProviderDisplayParts {
        guard let snapshot = state.lastSnapshot else {
            return PrimaryProviderDisplayParts(
                providerID: descriptor.id,
                displayName: descriptor.displayName,
                detailKind: descriptor.detailKind,
                leadingText: "",
                amountText: "--",
                amountValue: nil,
                amountTone: .neutral,
                trailingText: "",
                captionText: ""
            )
        }

        let presentation = ProviderSnapshotPresentation.make(from: snapshot, strings: strings)
        return PrimaryProviderDisplayParts(
            providerID: descriptor.id,
            displayName: descriptor.displayName,
            detailKind: descriptor.detailKind,
            leadingText: presentation.leadingText,
            amountText: presentation.amountText,
            amountValue: presentation.amountValue,
            amountTone: presentation.amountTone,
            trailingText: presentation.trailingText,
            captionText: presentation.captionText
        )
    }

    public static func quotaWindowDetailText(for window: QuotaWindowSnapshot) -> String {
        "\(formatPercentage(window.remainingPercentage))%"
    }

    public static func quotaWindowAmountText(for window: QuotaWindowSnapshot) -> String {
        formatPercentage(window.remainingPercentage)
    }

    public static func quotaWindowAmountValue(for window: QuotaWindowSnapshot) -> Double {
        amountValue(window.remainingPercentage, scale: 0)
    }

    static func primaryAmountText(forBalance total: Decimal) -> String {
        formatNumber(truncate(total, scale: 2), fractionDigits: 2)
    }

    static func primaryQuotaWindow(in usage: QuotaUsageSnapshot) -> QuotaWindowSnapshot? {
        usage.windows.first { $0.resolvedKind == .fiveHour } ?? usage.windows.first
    }

    static func quotaWindowText(
        for window: QuotaWindowSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let window else {
            return "--"
        }
        return "\(strings.quotaWindowLabel(window.label)) \(formatPercentage(window.remainingPercentage))%"
    }

    static func menuQuotaWindowText(for window: QuotaWindowSnapshot?) -> String {
        guard let window else {
            return "--"
        }
        let percentage = "\(formatPercentage(window.remainingPercentage))%"
        switch window.resolvedKind {
        case .fiveHour, .week, .month:
            return percentage
        case nil:
            return "\(window.label) \(percentage)"
        }
    }

    static func formatAmount(
        _ amount: Decimal,
        currency: String,
        fractionDigits: Int,
        includeCurrencyCode: Bool
    ) -> String {
        let currencyCode = currency.uppercased()
        let number = formatNumber(truncate(amount, scale: fractionDigits), fractionDigits: fractionDigits)

        if currencyCode == "CNY" {
            return includeCurrencyCode ? "¥\(number) \(currencyCode)" : "¥\(number)"
        }

        return includeCurrencyCode ? "\(number) \(currencyCode)" : "\(currencyCode) \(number)"
    }

    private static func formatPercentage(_ percentage: Decimal) -> String {
        formatNumber(truncate(percentage, scale: 0), fractionDigits: 0)
    }

    /// Credits are capped at two decimals for display. The backend reports up to ten
    /// fractional digits (for example `"balance": "64999.5574150000"`), which reads as a
    /// precision problem in the Console card even though the value is exact. The cap
    /// truncates instead of rounding so the shown balance never overstates what is left.
    private static func formatCredits(_ balance: Decimal) -> String {
        if balance == 0 {
            return "0"
        }
        return NSDecimalNumber(decimal: truncate(balance, scale: 2)).stringValue
    }

    static func formatNumber(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"
    }

    static func amountValue(_ amount: Decimal, scale: Int) -> Double {
        doubleValue(truncate(amount, scale: scale))
    }

    private static func doubleValue(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }

    private static func truncate(_ amount: Decimal, scale: Int) -> Decimal {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .down)
        return output
    }
}
