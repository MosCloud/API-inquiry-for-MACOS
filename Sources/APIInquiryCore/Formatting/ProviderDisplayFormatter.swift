import Foundation

public enum ProviderDisplayFormatter {
    public static func menuValueText(
        for state: BalanceState,
        isCredentialConfigured: Bool,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderValueFormatter.menuValueText(
            for: state,
            isCredentialConfigured: isCredentialConfigured,
            strings: strings
        )
    }

    public static func detailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderValueFormatter.detailText(for: snapshot, strings: strings)
    }

    public static func secondaryDetailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderValueFormatter.secondaryDetailText(for: snapshot, strings: strings)
    }

    public static func consoleDetailText(
        for snapshot: ProviderSnapshot?,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderValueFormatter.consoleDetailText(for: snapshot, strings: strings)
    }

    public static func primaryDisplayParts(
        provider: BalanceProvider,
        state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> PrimaryProviderDisplayParts {
        ProviderValueFormatter.primaryDisplayParts(provider: provider, state: state, strings: strings)
    }

    public static func primaryDisplayParts(
        descriptor: ProviderDescriptor,
        state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> PrimaryProviderDisplayParts {
        ProviderValueFormatter.primaryDisplayParts(descriptor: descriptor, state: state, strings: strings)
    }

    public static func statusText(
        for state: BalanceState,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderStatusFormatter.statusText(for: state, strings: strings)
    }

    public static func statusTone(for state: BalanceState) -> ProviderStatusTone {
        ProviderToneResolver.statusTone(for: state)
    }

    public static func summaryHealthTone(for state: BalanceState) -> ProviderAmountTone {
        ProviderToneResolver.summaryHealthTone(for: state)
    }

    public static func summaryBadgeText(
        for state: BalanceState,
        fallbackText: String,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> String {
        ProviderStatusFormatter.summaryBadgeText(
            for: state,
            fallbackText: fallbackText,
            strings: strings
        )
    }

    public static func resetText(for snapshot: ProviderSnapshot?) -> String? {
        ProviderValueFormatter.resetText(for: snapshot)
    }

    public static func quotaWindowDetailText(for window: QuotaWindowSnapshot) -> String {
        ProviderValueFormatter.quotaWindowDetailText(for: window)
    }

    public static func quotaWindowAmountText(for window: QuotaWindowSnapshot) -> String {
        ProviderValueFormatter.quotaWindowAmountText(for: window)
    }

    public static func quotaWindowAmountTone(for window: QuotaWindowSnapshot) -> ProviderAmountTone {
        ProviderToneResolver.remainingQuotaAmountTone(for: window.remainingPercentage)
    }
}
