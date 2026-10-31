public enum ProviderStatusFormatter {
    public static func statusText(
        for state: BalanceState,
        accessPurpose: ProviderAccessPurpose,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        switch state {
        case .notConfigured:
            return strings.notConfigured
        case .loading:
            return strings.refreshing
        case .loaded(let snapshot):
            return loadedStatusText(for: snapshot, accessPurpose: accessPurpose, strings: strings)
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

    /// The loaded-state wording is shared by the menu bar and the Console, and it follows
    /// what the provider sells — a subscription plan or a prepaid balance — rather than
    /// which snapshot payload it happens to use.
    public static func loadedStatusText(
        for snapshot: ProviderSnapshot,
        accessPurpose: ProviderAccessPurpose,
        strings: LocalizedStrings
    ) -> String {
        switch (accessPurpose, snapshot) {
        case (.prepaidBalance, .balance(let balance)):
            return balance.isAvailable ? strings.available : strings.balanceInsufficient
        case (.planQuota, .quotaUsage(let usage)):
            return usage.isAvailable ? strings.planAvailable : strings.planExhausted
        case (.planQuota, .balance(let balance)):
            return balance.isAvailable ? strings.available : strings.balanceInsufficient
        case (.prepaidBalance, .quotaUsage(let usage)):
            return usage.isAvailable ? strings.quotaAvailable : strings.quotaExhausted
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

        let healthTone = ProviderSnapshotPresentation.make(from: snapshot, strings: strings).healthTone
        if snapshot.isQuotaUsage {
            return quotaSummaryBadgeText(for: healthTone, fallbackText: fallbackText, strings: strings)
        }
        return balanceSummaryBadgeText(for: healthTone, fallbackText: fallbackText, strings: strings)
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
