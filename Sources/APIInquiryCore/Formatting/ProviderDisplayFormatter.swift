import Foundation

public struct PrimaryProviderDisplayParts: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailKind: ProviderDetailKind
    public let leadingText: String
    public let amountText: String
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
    public let lastRefreshText: String
    public let resetText: String?
}

public struct QuotaWindowDisplayRow: Equatable {
    public let label: String
    public let amountText: String
    public let amountTone: ProviderAmountTone
    public let suffixText: String
    public let detailText: String
    public let resetText: String?
    public let isAvailable: Bool
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

public enum ProviderDisplayFormatter {
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
            return "\(usage.windowLabel) \(formatPercentage(usage.usagePercentage))%"
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
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.usagePercentage))%"
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
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.usagePercentage))%"
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
            return "\(strings.quotaWindowLabel(usage.windowLabel)) \(formatPercentage(usage.usagePercentage))% \(strings.usedSuffix)"
        case .quotaUsage(let usage):
            return "\(quotaWindowText(for: primaryQuotaWindow(in: usage), strings: strings)) \(strings.compactRemainingSuffix)"
        default:
            return detailText(for: snapshot, strings: strings)
        }
    }

    public static func primaryDisplayParts(
        provider: BalanceProvider,
        state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> PrimaryProviderDisplayParts {
        guard let snapshot = state.lastSnapshot else {
            return PrimaryProviderDisplayParts(
                providerID: provider.id,
                displayName: provider.displayName,
                detailKind: .balance,
                leadingText: "",
                amountText: "--",
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
                providerID: provider.id,
                displayName: provider.displayName,
                detailKind: .balance,
                leadingText: currencyCode == "CNY" ? "¥" : "",
                amountText: amountText,
                amountTone: balanceAmountTone(for: balance.totalBalance),
                trailingText: currencyCode,
                captionText: ""
            )
        case .planUsage(let usage):
            return PrimaryProviderDisplayParts(
                providerID: provider.id,
                displayName: provider.displayName,
                detailKind: .planUsage,
                leadingText: "",
                amountText: formatPercentage(usage.usagePercentage),
                amountTone: planUsageAmountTone(for: usage.usagePercentage),
                trailingText: "% \(strings.usedSuffix)",
                captionText: strings.quotaWindowLabel(usage.windowLabel)
            )
        case .quotaUsage(let usage):
            let window = primaryQuotaWindow(in: usage)
            return PrimaryProviderDisplayParts(
                providerID: provider.id,
                displayName: provider.displayName,
                detailKind: .quotaUsage,
                leadingText: "",
                amountText: formatPercentage(window?.remainingPercentage ?? 0),
                amountTone: window.map { remainingQuotaAmountTone(for: $0.remainingPercentage) } ?? .neutral,
                trailingText: "% \(strings.remainingSuffix)",
                captionText: window.map { strings.quotaWindowLabel($0.label) } ?? ""
            )
        }
    }

    public static func statusText(
        for state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        switch state {
        case .notConfigured:
            return strings.notConfigured
        case .loading:
            return strings.refreshing
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? strings.available : strings.balanceInsufficient
            case .planUsage(let usage):
                return usage.isAvailable ? strings.planAvailable : strings.limitReached
            case .quotaUsage(let usage):
                return usage.isAvailable ? strings.quotaAvailable : strings.quotaExhausted
            }
        case .failed(_, let kind, _):
            switch kind {
            case .authenticationFailed:
                return strings.invalid
            case .usageLimitReached:
                return strings.limitReached
            case .planExpired:
                return strings.planExpired
            default:
                return strings.unavailable
            }
        }
    }

    public static func statusTone(for state: BalanceState) -> ProviderStatusTone {
        switch state {
        case .notConfigured:
            return .neutral
        case .loading:
            return .refreshing
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? .success : .warning
            case .planUsage(let usage):
                return usage.isAvailable ? .success : .warning
            case .quotaUsage(let usage):
                return usage.isAvailable ? .success : .warning
            }
        case .failed:
            return .warning
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

    public static func quotaWindowAmountTone(for window: QuotaWindowSnapshot) -> ProviderAmountTone {
        remainingQuotaAmountTone(for: window.remainingPercentage)
    }

    private static func primaryQuotaWindow(in usage: QuotaUsageSnapshot) -> QuotaWindowSnapshot? {
        usage.windows.first { $0.label == "5h" } ?? usage.windows.first
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
        return "\(window.label) \(formatPercentage(window.remainingPercentage))%"
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

    private static func balanceAmountTone(for amount: Decimal) -> ProviderAmountTone {
        if amount >= Decimal(50) {
            return .good
        }
        if amount >= Decimal(10) {
            return .warning
        }
        return .critical
    }

    private static func planUsageAmountTone(for usagePercentage: Decimal) -> ProviderAmountTone {
        if usagePercentage <= Decimal(40) {
            return .good
        }
        if usagePercentage <= Decimal(80) {
            return .warning
        }
        return .critical
    }

    private static func remainingQuotaAmountTone(for remainingPercentage: Decimal) -> ProviderAmountTone {
        if remainingPercentage >= Decimal(60) {
            return .good
        }
        if remainingPercentage >= Decimal(20) {
            return .warning
        }
        return .critical
    }

    private static func formatNumber(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"
    }

    private static func truncate(_ amount: Decimal, scale: Int) -> Decimal {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .down)
        return output
    }
}
