import Foundation

/// Which number a surface should show for a provider.
///
/// Derived once, in `ProviderSnapshotPresentation.make`, so the menu bar, the hero and the
/// secondary rows cannot disagree about the same snapshot (#123). Before this, each surface
/// re-picked a window and the panel could show a healthy 100% five-hour window while the
/// weekly window was drained and the account still held credits.
public enum QuotaDisplayMode: Equatable {
    /// A prepaid balance (or any `.balance` payload). Unchanged by #123.
    case amount
    /// The usual quota windows.
    case percentage
    /// A window is drained and credits can pay for more.
    case credits
    /// A window is drained and there is nothing to spend: the percentage stays, so the
    /// menu bar reads `0%` rather than claiming a zero credit balance (#123).
    case exhaustedNoCredit
}

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
    /// Which kind of number `menuValueText` / `amountText` carry.
    public let displayMode: QuotaDisplayMode
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
                    fractionDigits: isCredits ? 2 : 1,
                    includeCurrencyCode: false,
                    includeSymbol: false,
                    strings: strings
                ),
                displayMode: .amount
            )

        case .quotaUsage(let usage):
            // One decision per snapshot (#123): the surfaces read `displayMode` instead of
            // each picking a window, so the menu bar, the hero and the secondary rows can
            // never contradict each other about the same payload.
            let drained = ProviderValueFormatter.drainedQuotaWindow(in: usage)
            let displayMode: QuotaDisplayMode
            if drained == nil {
                displayMode = .percentage
            } else if usage.creditsSupported,
                      ProviderValueFormatter.hasSpendableCredits(usage.credits) {
                displayMode = .credits
            } else if usage.creditsSupported {
                displayMode = .exhaustedNoCredit
            } else {
                displayMode = .percentage
            }

            if displayMode == .credits, let credits = usage.credits {
                return ProviderSnapshotPresentation(
                    menuValueText: ProviderValueFormatter.creditsMenuText(for: credits, strings: strings),
                    detailText: ProviderValueFormatter.creditsAmountText(for: credits, strings: strings),
                    // The Console keeps its own quota wording: #123 is a panel change only
                    // (Q6), and the credits cell there already reports the balance.
                    consoleDetailText: ProviderValueFormatter.quotaWindowText(
                        for: ProviderValueFormatter.primaryQuotaWindow(in: usage),
                        strings: strings
                    ) + " " + strings.remainingSuffix(.full),
                    amountText: ProviderValueFormatter.creditsAmountText(for: credits, strings: strings),
                    amountValue: ProviderValueFormatter.creditsAmountValue(for: credits),
                    // Q5: the tone mapping stays exactly as it was, so the number is coloured
                    // by the window that ran out, not by the credits that remain.
                    amountTone: ProviderToneResolver.remainingQuotaAmountTone(
                        for: drained?.remainingPercentage ?? 0
                    ),
                    healthTone: ProviderToneResolver.aggregateAmountTone(
                        usage.windows.map { ProviderToneResolver.remainingQuotaAmountTone(for: $0.remainingPercentage) }
                    ),
                    leadingText: "",
                    trailingText: strings.creditUnitLabel,
                    // The caption keeps the exhausted window on screen — 「Week 0%」 above
                    // the credits — so the number never loses the reason it is there. It
                    // reuses the balance layout's caption slot instead of adding a row, so
                    // the hero keeps its height (#123).
                    captionText: ProviderValueFormatter.quotaWindowText(for: drained, strings: strings),
                    isAvailable: usage.isAvailable,
                    planName: usage.planName,
                    grantedBalanceText: nil,
                    compactAmountText: ProviderValueFormatter.creditsAmountText(for: credits, strings: strings),
                    displayMode: .credits
                )
            }

            // `exhaustedNoCredit` keeps the percentage path but focuses the drained window,
            // so a `0%` in the menu bar never sits beside a 100% hero (#123, Q7). A provider
            // without credits keeps its usual focus, because nothing changed for it.
            let window = (displayMode == .exhaustedNoCredit ? drained : nil)
                ?? ProviderValueFormatter.primaryQuotaWindow(in: usage)
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
                compactAmountText: nil,
                displayMode: displayMode
            )
        }
    }
}
