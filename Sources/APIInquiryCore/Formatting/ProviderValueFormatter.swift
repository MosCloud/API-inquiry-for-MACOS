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

        switch snapshot {
        case .balance(let balance):
            return formatAmount(balance.totalBalance, currency: balance.currency, fractionDigits: 1, includeCurrencyCode: false)
        case .planUsage(let usage):
            return "\(formatPercentage(usage.remainingPercentage))%"
        case .quotaUsage(let usage):
            return menuQuotaWindowText(for: primaryQuotaWindow(in: usage))
        }
    }

    public static func detailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let snapshot else {
            return "--"
        }

        switch snapshot {
        case .balance(let balance):
            return formatAmount(balance.totalBalance, currency: balance.currency, fractionDigits: 2, includeCurrencyCode: true)
        case .planUsage(let usage):
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.remainingPercentage))%"
        case .quotaUsage(let usage):
            return quotaWindowText(for: primaryQuotaWindow(in: usage), strings: strings)
        }
    }

    public static func secondaryDetailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let snapshot else {
            return "--"
        }

        switch snapshot {
        case .planUsage(let usage):
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.remainingPercentage))%"
        default:
            return detailText(for: snapshot, strings: strings)
        }
    }

    public static func consoleDetailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let snapshot else {
            return "--"
        }

        switch snapshot {
        case .planUsage(let usage):
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.remainingPercentage))% \(strings.remainingSuffix)"
        case .quotaUsage(let usage):
            return "\(quotaWindowText(for: primaryQuotaWindow(in: usage), strings: strings)) \(strings.compactRemainingSuffix)"
        default:
            return detailText(for: snapshot, strings: strings)
        }
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

        switch snapshot {
        case .balance(let balance):
            let currencyCode = balance.currency.uppercased()
            let amountText = formatNumber(truncate(balance.totalBalance, scale: 2), fractionDigits: 2)
            return PrimaryProviderDisplayParts(
                providerID: descriptor.id,
                displayName: descriptor.displayName,
                detailKind: .balance,
                leadingText: currencyCode == "CNY" ? "¥" : "",
                amountText: amountText,
                amountValue: amountValue(balance.totalBalance, scale: 2),
                amountTone: ProviderToneResolver.balanceAmountTone(for: balance.totalBalance),
                trailingText: currencyCode,
                captionText: ""
            )
        case .planUsage(let usage):
            let remainingPercentage = truncate(usage.remainingPercentage, scale: 0)
            return PrimaryProviderDisplayParts(
                providerID: descriptor.id,
                displayName: descriptor.displayName,
                detailKind: .planUsage,
                leadingText: "",
                amountText: formatNumber(remainingPercentage, fractionDigits: 0),
                amountValue: doubleValue(remainingPercentage),
                amountTone: ProviderToneResolver.remainingQuotaAmountTone(for: usage.remainingPercentage),
                trailingText: "% \(strings.remainingSuffix)",
                captionText: strings.quotaWindowLabel(usage.windowLabel)
            )
        case .quotaUsage(let usage):
            let window = primaryQuotaWindow(in: usage)
            let remainingPercentage = window.map { truncate($0.remainingPercentage, scale: 0) }
            return PrimaryProviderDisplayParts(
                providerID: descriptor.id,
                displayName: descriptor.displayName,
                detailKind: .quotaUsage,
                leadingText: "",
                amountText: remainingPercentage.map { formatNumber($0, fractionDigits: 0) } ?? "0",
                amountValue: remainingPercentage.map(doubleValue),
                amountTone: window.map { ProviderToneResolver.remainingQuotaAmountTone(for: $0.remainingPercentage) } ?? .neutral,
                trailingText: "% \(strings.remainingSuffix)",
                captionText: window.map { strings.quotaWindowLabel($0.label) } ?? ""
            )
        }
    }

    public static func resetText(for snapshot: ProviderSnapshot?) -> String? {
        guard case .planUsage(let usage) = snapshot,
              let resetAt = usage.resetAt else {
            return nil
        }

        return LastRefreshTimeFormatter().resetText(for: resetAt)
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

    static func primaryQuotaWindow(in usage: QuotaUsageSnapshot) -> QuotaWindowSnapshot? {
        usage.windows.first { $0.resolvedKind == .fiveHour } ?? usage.windows.first
    }

    private static func quotaWindowText(
        for window: QuotaWindowSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard let window else {
            return "--"
        }
        return "\(strings.quotaWindowLabel(window.label)) \(formatPercentage(window.remainingPercentage))%"
    }

    private static func menuQuotaWindowText(for window: QuotaWindowSnapshot?) -> String {
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

    private static func formatAmount(
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

    private static func formatNumber(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"
    }

    private static func amountValue(_ amount: Decimal, scale: Int) -> Double {
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
