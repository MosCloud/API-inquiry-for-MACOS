import APIInquiryCore
import Foundation

enum ProviderValueFormatterTests {
    static func run(using harness: TestHarness) {
        testCreditsBalanceTruncatesToTwoDecimals(using: harness)
        testCreditsBalanceDropsInsignificantTrailingZeros(using: harness)
        testCreditsBalanceNeverRoundsUp(using: harness)
        testCreditsBalanceTruncatesTinyFractionToZero(using: harness)
        testCreditsBalanceKeepsExplicitZero(using: harness)
        testCreditsBalanceUsesLocalizedUnlimitedText(using: harness)
        testCreditsBalanceWithoutCreditsShowsPlaceholder(using: harness)
        testNegativeCreditsBalanceShowsPlaceholder(using: harness)
        testCreditsBalanceLocalizesTheUnit(using: harness)
        testCreditsAmountTextIsWholeCredits(using: harness)
    }

    private static func testCreditsBalanceTruncatesToTwoDecimals(using harness: TestHarness) {
        let text = ProviderValueFormatter.creditsBalanceText(
            for: makeSnapshot(credits: .balance(decimal("64999.5574150000"))),
            strings: LocalizedStrings(language: .zh)
        )

        // The Console's own cell is outside #126's scope (Q2), but the unit there is now
        // localized, so Chinese reads 「积分」 rather than `Credits` (Q9/Q10).
        harness.expectEqual(text, "64999.55 积分", "live codex credits balance keeps two decimals in the console")
    }

    private static func testCreditsBalanceDropsInsignificantTrailingZeros(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("12.50")))),
            "12.5 Credits",
            "codex credits balance drops trailing zeros"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("65000")))),
            "65000 Credits",
            "codex credits balance leaves whole numbers intact"
        )
    }

    private static func testCreditsBalanceNeverRoundsUp(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("0.005")))),
            "0 Credits",
            "codex credits balance drops a sub-cent remainder instead of rounding up"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("64999.995")))),
            "64999.99 Credits",
            "codex credits balance never carries into the next whole credit"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("99.999")))),
            "99.99 Credits",
            "codex credits balance keeps two digits from rounding up"
        )
    }

    private static func testCreditsBalanceTruncatesTinyFractionToZero(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("0.004")))),
            "0 Credits",
            "codex credits balance below one cent truncates to zero"
        )
    }

    private static func testCreditsBalanceKeepsExplicitZero(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(0))),
            "0 Credits",
            "codex explicit zero credits"
        )
    }

    private static func testCreditsBalanceUsesLocalizedUnlimitedText(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(
                for: makeSnapshot(credits: .unlimited),
                strings: LocalizedStrings(language: .zh)
            ),
            "无限",
            "chinese unlimited credits"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(
                for: makeSnapshot(credits: .unlimited),
                strings: LocalizedStrings(language: .en)
            ),
            "Unlimited",
            "english unlimited credits"
        )
    }

    private static func testCreditsBalanceWithoutCreditsShowsPlaceholder(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: nil)),
            "--",
            "missing codex credits shows placeholder"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(
                for: .balance(BalanceSnapshot(
                    providerID: .deepseek,
                    totalBalance: 31,
                    currency: "CNY",
                    isAvailable: true,
                    grantedBalance: nil,
                    toppedUpBalance: nil,
                    fetchedAt: Date(timeIntervalSince1970: 0)
                ))
            ),
            "--",
            "non-quota snapshot has no credits balance"
        )
    }

    private static func testNegativeCreditsBalanceShowsPlaceholder(using harness: TestHarness) {
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .balance(decimal("-2.5")))),
            "--",
            "negative codex credits shows placeholder"
        )
    }

    private static func makeSnapshot(credits: CodexCredits?) -> ProviderSnapshot {
        .quotaUsage(QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(
                    label: "5h",
                    kind: .fiveHour,
                    remainingPercentage: 94,
                    resetAt: nil,
                    isAvailable: true
                )
            ],
            fetchedAt: Date(timeIntervalSince1970: 0),
            credits: credits
        ))
    }

    private static func decimal(_ rawValue: String) -> Decimal {
        Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX"))!
    }

    /// Q3/Q7 (#126): the unit is `Credits` in English and 「积分」 in Chinese. It used to
    /// say `Credits` in both, because the string was hard-coded past `LocalizedStrings`.
    private static func testCreditsBalanceLocalizesTheUnit(using harness: TestHarness) {
        let english = LocalizedStrings(language: .en)
        let chinese = LocalizedStrings(language: .zh)
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(
                for: makeSnapshot(credits: .balance(decimal("12.5"))),
                strings: english
            ),
            "12.5 Credits",
            "english names the unit in title case"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(
                for: makeSnapshot(credits: .balance(decimal("12.5"))),
                strings: chinese
            ),
            "12.5 积分",
            "chinese names the unit localized, not Credits"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsBalanceText(for: makeSnapshot(credits: .unlimited), strings: chinese),
            chinese.creditsUnlimited,
            "unlimited stays localized as before"
        )
    }

    /// Q1 (#126): every credit surface reads whole credits truncated toward zero, so the
    /// panel and the menu bar cannot disagree about the same balance.
    private static func testCreditsAmountTextIsWholeCredits(using harness: TestHarness) {
        let english = LocalizedStrings(language: .en)
        // The number that exposed the split: the bar said 4583.5 while the panel said
        // 4583.58, and neither matched the provider's own 4583.58.
        harness.expectEqual(
            ProviderValueFormatter.creditsAmountText(for: .balance(decimal("4583.58")), strings: english),
            "4583",
            "the hero reads whole credits"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsAmountText(for: .balance(decimal("53064.4233895001")), strings: english),
            "53064",
            "a long fraction still truncates to the integer part"
        )
        // Truncation, not rounding: 0.999 must not become 1.
        harness.expectEqual(
            ProviderValueFormatter.creditsAmountText(for: .balance(decimal("0.999")), strings: english),
            "0",
            "truncation never carries into the next credit"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsAmountText(for: .balance(decimal("-1")), strings: english),
            "--",
            "a negative balance keeps its placeholder"
        )
        harness.expectEqual(
            ProviderValueFormatter.creditsAmountText(for: .unlimited, strings: english),
            english.creditsUnlimited,
            "unlimited is not a number"
        )
        // Money is a different kind of number and keeps its decimal (Q8).
        harness.expectEqual(
            ProviderValueFormatter.formatAmount(
                decimal("29.56"),
                currency: "CNY",
                fractionDigits: 1,
                includeCurrencyCode: false,
                includeSymbol: false,
                strings: english
            ),
            "29.5",
            "money keeps one decimal, unaffected by the credit rule"
        )
    }
}
