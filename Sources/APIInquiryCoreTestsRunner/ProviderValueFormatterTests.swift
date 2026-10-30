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
    }

    private static func testCreditsBalanceTruncatesToTwoDecimals(using harness: TestHarness) {
        let text = ProviderValueFormatter.creditsBalanceText(
            for: makeSnapshot(credits: .balance(decimal("64999.5574150000"))),
            strings: LocalizedStrings(language: .zh)
        )

        harness.expectEqual(text, "64999.55 Credits", "live codex credits balance truncates to two decimals")
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
}
