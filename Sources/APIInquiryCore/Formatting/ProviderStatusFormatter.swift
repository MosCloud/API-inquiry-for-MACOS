public enum ProviderStatusFormatter {
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

    public static func summaryBadgeText(
        for state: BalanceState,
        fallbackText: String,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        guard case .loaded(let snapshot) = state else {
            return fallbackText
        }

        switch snapshot {
        case .balance(let balance):
            return balanceSummaryBadgeText(
                for: ProviderToneResolver.balanceAmountTone(for: balance.totalBalance),
                fallbackText: fallbackText,
                strings: strings
            )
        case .planUsage(let usage):
            return quotaSummaryBadgeText(
                for: ProviderToneResolver.planUsageAmountTone(for: usage.usagePercentage),
                fallbackText: fallbackText,
                strings: strings
            )
        case .quotaUsage(let usage):
            return quotaSummaryBadgeText(
                for: ProviderToneResolver.aggregateAmountTone(
                    usage.windows.map { ProviderToneResolver.remainingQuotaAmountTone(for: $0.remainingPercentage) }
                ),
                fallbackText: fallbackText,
                strings: strings
            )
        }
    }

    private static func balanceSummaryBadgeText(
        for tone: ProviderAmountTone,
        fallbackText: String,
        strings: LocalizedStrings
    ) -> String {
        switch tone {
        case .neutral:
            return fallbackText
        case .good:
            return strings.balanceSufficient
        case .warning:
            return strings.balanceLow
        case .critical:
            return strings.balanceCritical
        }
    }

    private static func quotaSummaryBadgeText(
        for tone: ProviderAmountTone,
        fallbackText: String,
        strings: LocalizedStrings
    ) -> String {
        switch tone {
        case .neutral:
            return fallbackText
        case .good:
            return strings.quotaSufficient
        case .warning:
            return strings.quotaLow
        case .critical:
            return strings.quotaCritical
        }
    }
}
