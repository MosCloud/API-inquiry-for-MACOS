import Foundation

public struct PrimaryProviderDisplayParts: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailKind: ProviderDetailKind
    public let leadingText: String
    public let amountText: String
    public let trailingText: String
    public let captionText: String
}

public struct ProviderDetailRow: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailText: String
    public let statusText: String
    public let statusTone: ProviderStatusTone
    public let lastRefreshText: String
    public let resetText: String?
}

public enum ProviderStatusTone: Equatable {
    case neutral
    case success
    case refreshing
    case warning
}

public enum ProviderDisplayFormatter {
    public static func menuValueText(for state: BalanceState, isCredentialConfigured: Bool) -> String {
        if case .notConfigured = state {
            return isCredentialConfigured ? "--" : "Setup"
        }

        guard let snapshot = state.lastSnapshot else {
            return "--"
        }

        switch snapshot {
        case .balance(let balance):
            return formatAmount(balance.totalBalance, currency: balance.currency, fractionDigits: 1, includeCurrencyCode: false)
        case .planUsage(let usage):
            return "\(usage.windowLabel) \(formatPercentage(usage.usagePercentage))%"
        }
    }

    public static func detailText(for snapshot: ProviderSnapshot?) -> String {
        guard let snapshot else {
            return "--"
        }

        switch snapshot {
        case .balance(let balance):
            return formatAmount(balance.totalBalance, currency: balance.currency, fractionDigits: 2, includeCurrencyCode: true)
        case .planUsage(let usage):
            return "\(usage.windowLabel) \(formatPercentage(usage.usagePercentage))%"
        }
    }

    public static func primaryDisplayParts(
        provider: BalanceProvider,
        state: BalanceState
    ) -> PrimaryProviderDisplayParts {
        guard let snapshot = state.lastSnapshot else {
            return PrimaryProviderDisplayParts(
                providerID: provider.id,
                displayName: provider.displayName,
                detailKind: .balance,
                leadingText: "",
                amountText: "--",
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
                trailingText: "% used",
                captionText: usage.windowLabel
            )
        }
    }

    public static func statusText(for state: BalanceState) -> String {
        switch state {
        case .notConfigured:
            return "Not configured"
        case .loading:
            return "Refreshing"
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? "Available" : "Balance insufficient"
            case .planUsage(let usage):
                return usage.isAvailable ? "Plan available" : "Limit reached"
            }
        case .failed(_, let kind, _):
            switch kind {
            case .authenticationFailed:
                return "Invalid"
            case .usageLimitReached:
                return "Limit reached"
            case .planExpired:
                return "Plan expired"
            default:
                return "Unavailable"
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
