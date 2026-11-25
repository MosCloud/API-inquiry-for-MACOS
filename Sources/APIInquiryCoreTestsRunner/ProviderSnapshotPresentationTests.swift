import APIInquiryCore
import Foundation

enum ProviderSnapshotPresentationTests {
    static func run(using harness: TestHarness) {
        testBalancePresentation(using: harness)
        testQuotaPresentationFocusesFiveHourWindow(using: harness)
        testHealthToneAggregatesWindows(using: harness)
        testExhaustedWindowFallsBackToCredits(using: harness)
        testFiveHourZeroAloneFallsBackToCredits(using: harness)
        testZeroCreditsKeepsZeroPercent(using: harness)
        testMissingCreditsKeepsPercentage(using: harness)
        testUnlimitedCreditsUseTheInfinityGlyph(using: harness)
        testExhaustedFocusMovesToTheDrainedWindow(using: harness)
        testCreditsAboveSixDigitsNeedNoShrinking(using: harness)
        testOtherProvidersKeepTheirPercentageWhenDrained(using: harness)
        testConsoleDetailIgnoresThePanelFocus(using: harness)
    }

    // MARK: - Credit fallback (v0.4.4, #123)

    /// The weekly window is drained but credits are left: the panel must show the credits,
    /// not a 100% five-hour window that hides the exhaustion.
    private static func testExhaustedWindowFallsBackToCredits(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: .balance(Decimal(string: "53064.4233895001")!)))
        )

        harness.expectEqual(presentation.displayMode, .credits, "exhausted window selects the credits mode")
        harness.expectEqual(presentation.menuValueText, "53064", "menu bar keeps whole credits and no unit")
        harness.expectEqual(presentation.amountText, "53064.42", "hero amount truncates credits to two decimals")
        harness.expectEqual(presentation.trailingText, "credits", "the hero suffix carries the unit")
        harness.expectEqual(presentation.captionText, "Weekly 0%", "the caption keeps the drained window above the credits")
        harness.expectEqual(presentation.leadingText, "", "credits carry no currency symbol")
    }

    /// Either window counts, not just the long one.
    private static func testFiveHourZeroAloneFallsBackToCredits(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 0, week: 48, credits: .balance(Decimal(12))))
        )

        harness.expectEqual(presentation.displayMode, .credits, "the five-hour window alone triggers the fallback")
        harness.expectEqual(presentation.menuValueText, "12", "credits keep whole numbers only")
    }

    /// Q7: exhausted with nothing to spend stays a percentage, so the menu bar reads 0%.
    private static func testZeroCreditsKeepsZeroPercent(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: .balance(0)))
        )

        harness.expectEqual(presentation.displayMode, .exhaustedNoCredit, "zero credits are their own mode")
        harness.expectEqual(presentation.menuValueText, "0%", "the menu bar falls back to the drained window")
        harness.expectEqual(presentation.amountText, "0", "the number is the drained window, not a zero balance")
    }

    /// A provider that never sells credits must not change behaviour at all.
    private static func testMissingCreditsKeepsPercentage(using harness: TestHarness) {
        let unsupported = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: nil, creditsSupported: false))
        )
        harness.expectEqual(unsupported.displayMode, .percentage, "a provider without credits keeps the percentage")
        harness.expectEqual(unsupported.menuValueText, "100%", "without credits the five-hour window still leads")

        // Supported but unreported is a different state: the account has the concept and
        // could not report it, so it is treated like a zero balance (Q7), not like a
        // provider that has no such feature.
        let unreported = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: nil, creditsSupported: true))
        )
        harness.expectEqual(unreported.displayMode, .exhaustedNoCredit, "a missing credit block falls back to 0%")
        harness.expectEqual(unreported.menuValueText, "0%", "the drained window supplies the number")
    }

    private static func testUnlimitedCreditsUseTheInfinityGlyph(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 0, week: 0, credits: .unlimited))
        )

        harness.expectEqual(presentation.displayMode, .credits, "unlimited credits still replace the percentage")
        harness.expectEqual(presentation.menuValueText, "∞", "the menu bar uses one narrow glyph for unlimited")
        harness.expectEqual(presentation.amountText, "Unlimited", "the hero spells unlimited out")
    }

    /// Q7 without credits: the focused window has to be the drained one, or the hero would
    /// claim 100% while the menu bar says 0%.
    private static func testExhaustedFocusMovesToTheDrainedWindow(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: .balance(0)))
        )

        harness.expectEqual(presentation.captionText, "Weekly", "the drained weekly window takes the hero")
        harness.expectEqual(presentation.detailText, "Weekly 0%", "detail names the drained window")
    }

    /// Six digits fit at the default hero size; seven are the documented step down.
    private static func testCreditsAboveSixDigitsNeedNoShrinking(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 0, week: 0, credits: .balance(Decimal(string: "1234567.891")!)))
        )

        harness.expectEqual(presentation.amountText, "1234567.89", "large credit balances keep every digit")
        harness.expectTrue((presentation.amountValue ?? 0) > 1_234_567.8, "the transition value follows the text")
    }

    /// The fallback is Codex's capability, not a general rule: a provider that never sells
    /// credits must keep its old behaviour even when drained (#123).
    private static func testOtherProvidersKeepTheirPercentageWhenDrained(using harness: TestHarness) {
        let openCode = QuotaUsageSnapshot(
            providerID: .opencode,
            planName: "OpenCode Go",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(100),
                                    resetAt: nil, isAvailable: true),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(0),
                                    resetAt: nil, isAvailable: false)
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let presentation = ProviderSnapshotPresentation.make(from: .quotaUsage(openCode))

        harness.expectEqual(presentation.displayMode, .percentage, "opencode keeps the percentage path")
        harness.expectEqual(presentation.menuValueText, "100%", "opencode still leads with the five-hour window")
    }

    /// Q6: the Console is frozen. Its detail text keeps reporting the provider's leading
    /// window even when the panel has switched focus to a drained one.
    private static func testConsoleDetailIgnoresThePanelFocus(using harness: TestHarness) {
        let presentation = ProviderSnapshotPresentation.make(
            from: .quotaUsage(codexSnapshot(fiveHour: 100, week: 0, credits: .balance(0)))
        )

        harness.expectEqual(presentation.captionText, "Weekly", "the panel focuses the drained window")
        harness.expectEqual(presentation.consoleDetailText, "5h 100% remaining", "the console keeps the leading window")
    }

    private static func codexSnapshot(
        fiveHour: Decimal,
        week: Decimal,
        credits: CodexCredits?,
        creditsSupported: Bool = true
    ) -> QuotaUsageSnapshot {
        QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: fiveHour,
                                    resetAt: nil, isAvailable: fiveHour > 0),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: week,
                                    resetAt: nil, isAvailable: week > 0)
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000),
            credits: credits,
            creditsSupported: creditsSupported
        )
    }

    /// #64 P5: one pass derives every value the surfaces read, so the formatters no longer
    /// each re-interpret the payload.
    private static func testBalancePresentation(using harness: TestHarness) {
        let balance = BalanceSnapshot(
            providerID: .deepseek,
            totalBalance: Decimal(string: "68.65")!,
            currency: "CNY",
            isAvailable: true,
            grantedBalance: Decimal(string: "10.00"),
            toppedUpBalance: Decimal(string: "58.65"),
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let presentation = ProviderSnapshotPresentation.make(from: .balance(balance))

        harness.expectEqual(presentation.menuValueText, "¥68.6", "balance menu value truncates to one decimal and keeps the symbol")
        harness.expectEqual(presentation.detailText, "¥68.65 CNY", "balance detail keeps the code")
        harness.expectEqual(presentation.consoleDetailText, presentation.detailText, "balance console text matches detail")
        harness.expectEqual(presentation.amountText, "68.65", "balance amount text")
        harness.expectEqual(presentation.leadingText, "¥", "balance leading symbol")
        harness.expectEqual(presentation.trailingText, "CNY", "balance trailing code")
        harness.expectEqual(presentation.captionText, "", "balance has no window caption")
        harness.expectEqual(presentation.planName, nil, "balance has no plan name")
        harness.expectEqual(presentation.isAvailable, true, "balance availability")
        harness.expectEqual(
            presentation.grantedBalanceText,
            "¥10.00 CNY",
            "granted balance reads like the total: symbol, two decimals, currency code"
        )
    }

    private static func testQuotaPresentationFocusesFiveHourWindow(using harness: TestHarness) {
        let snapshot = QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(48),
                                    resetAt: nil, isAvailable: true),
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(72),
                                    resetAt: nil, isAvailable: true)
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let presentation = ProviderSnapshotPresentation.make(from: .quotaUsage(snapshot))

        harness.expectEqual(presentation.menuValueText, "72%", "quota menu value follows the five-hour window")
        harness.expectEqual(presentation.detailText, "5h 72%", "quota detail follows the five-hour window")
        harness.expectEqual(presentation.consoleDetailText, "5h 72% remaining", "console spells the suffix out")
        harness.expectEqual(presentation.captionText, "5h", "caption names the focused window")
        harness.expectEqual(presentation.planName, "Plus", "plan name is carried through")
    }

    private static func testHealthToneAggregatesWindows(using harness: TestHarness) {
        let healthy = QuotaUsageSnapshot(
            providerID: .opencode,
            planName: "OpenCode Go",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(95),
                                    resetAt: nil, isAvailable: true),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(10),
                                    resetAt: nil, isAvailable: true)
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let tight = QuotaUsageSnapshot(
            providerID: .opencode,
            planName: "OpenCode Go",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(80),
                                    resetAt: nil, isAvailable: true),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(70),
                                    resetAt: nil, isAvailable: true)
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )

        harness.expectEqual(
            ProviderSnapshotPresentation.make(from: .quotaUsage(healthy)).healthTone,
            ProviderToneResolver.remainingQuotaAmountTone(for: Decimal(10)),
            "health tone follows the scarcest window"
        )
        harness.expectEqual(
            ProviderSnapshotPresentation.make(from: .quotaUsage(tight)).healthTone,
            ProviderToneResolver.remainingQuotaAmountTone(for: Decimal(70)),
            "health tone stays healthy when every window has room"
        )
    }
}
