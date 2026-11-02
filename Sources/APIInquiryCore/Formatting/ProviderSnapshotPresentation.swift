import Foundation

/// Everything the surfaces need to draw one provider, derived in a single pass.
///
/// Before this type every formatter switched on `ProviderSnapshot` again
/// (`ProviderValueFormatter` four times, `ProviderStatusFormatter` and
/// `ProviderToneResolver` one each), so the "which window is the primary one" and "is it
/// healthy" decisions were re-derived per call. They now happen here once, and the
/// formatters read plain fields. (#64 P5)
public struct ProviderSnapshotPresentation: Equatable {
    /// Bare value for the menu bar: `30.00` or `72`.
    public let menuValueText: String
    /// Provider row detail: `¥30.00 CNY` or `5 时 72%`.
    public let detailText: String
    /// Console detail: the full-word variant of the same value.
    public let consoleDetailText: String
    /// Big-number text on the primary panel area.
    public let amountText: String
    public let amountValue: Double?
    /// Tone of the primary window (or the balance).
    public let amountTone: ProviderAmountTone
    /// Tone across every window, used by the Console health dot.
    public let healthTone: ProviderAmountTone
    public let leadingText: String
    public let trailingText: String
    public let captionText: String
    public let isAvailable: Bool
    public let planName: String?
    /// Balance providers may report how much of the total is granted credit; formatted
    /// like `detailText` so both money columns read the same.
    public let grantedBalanceText: String?
    /// Money without the currency symbol, at the same precision the menu bar uses (one
    /// decimal, truncated). The secondary grid carries the currency in its own column, so a
    /// symbol here would say the same thing twice.
    public let compactAmountText: String?
}

public extension ProviderSnapshotPresentation {
    static func make(
        from snapshot: ProviderSnapshot,
        strings: LocalizedStrings = LocalizedStrings(language: .en)
    ) -> ProviderSnapshotPresentation {
        switch snapshot {
        case .balance(let balance):
            let currencyCode = balance.currency.uppercased()
            let isCredits = ProviderValueFormatter.isCreditCurrency(balance.currency)
            // Credits have no symbol and a localised unit, so the trailing cell carries
            // the unit word (中文「积分」) instead of a currency code.
            let trailingText = isCredits
                ? strings.creditUnitLabel
                : currencyCode
            let detail = ProviderValueFormatter.formatAmount(
                balance.totalBalance,
                currency: balance.currency,
                fractionDigits: 2,
                includeCurrencyCode: true,
                strings: strings
            )
            return ProviderSnapshotPresentation(
                menuValueText: ProviderValueFormatter.formatAmount(
                    balance.totalBalance,
                    currency: balance.currency,
                    fractionDigits: 1,
                    includeCurrencyCode: false,
                    strings: strings
                ),
                detailText: detail,
                consoleDetailText: detail,
                amountText: ProviderValueFormatter.primaryAmountText(forBalance: balance.totalBalance),
                amountValue: ProviderValueFormatter.amountValue(balance.totalBalance, scale: 2),
                amountTone: ProviderToneResolver.balanceAmountTone(for: balance.totalBalance),
                healthTone: ProviderToneResolver.balanceAmountTone(for: balance.totalBalance),
                leadingText: currencyCode == "CNY" ? "¥" : "",
                trailingText: trailingText,
                captionText: "",
                isAvailable: balance.isAvailable,
                planName: nil,
                grantedBalanceText: balance.grantedBalance.map {
                    ProviderValueFormatter.formatAmount(
                        $0,
                        currency: balance.currency,
                        fractionDigits: 2,
                        includeCurrencyCode: true,
                        strings: strings
                    )
                },
                compactAmountText: ProviderValueFormatter.formatAmount(
                    balance.totalBalance,
                    currency: balance.currency,
                    fractionDigits: 1,
                    includeCurrencyCode: false,
                    includeSymbol: false,
                    strings: strings
                )
            )

        case .quotaUsage(let usage):
            let window = ProviderValueFormatter.primaryQuotaWindow(in: usage)
            let detail = ProviderValueFormatter.quotaWindowText(for: window, strings: strings)
            let amountTone = window.map {
                ProviderToneResolver.remainingQuotaAmountTone(for: $0.remainingPercentage)
            } ?? .neutral
            return ProviderSnapshotPresentation(
                menuValueText: ProviderValueFormatter.menuQuotaWindowText(for: window),
                detailText: detail,
                consoleDetailText: "\(detail) \(strings.remainingSuffix(.full))",
                amountText: window.map { ProviderValueFormatter.quotaWindowAmountText(for: $0) } ?? "0",
                amountValue: window.map { ProviderValueFormatter.quotaWindowAmountValue(for: $0) },
                amountTone: amountTone,
                healthTone: ProviderToneResolver.aggregateAmountTone(
                    usage.windows.map { ProviderToneResolver.remainingQuotaAmountTone(for: $0.remainingPercentage) }
                ),
                leadingText: "",
                trailingText: "% \(strings.remainingSuffix(.full))",
                captionText: window.map { strings.quotaWindowLabel($0.label) } ?? "",
                isAvailable: usage.isAvailable,
                planName: usage.planName,
                grantedBalanceText: nil,
                compactAmountText: nil
            )
        }
    }
}
