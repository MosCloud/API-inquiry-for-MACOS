import APIInquiryCore
import Foundation

enum ProviderSnapshotPresentationTests {
    static func run(using harness: TestHarness) {
        testBalancePresentation(using: harness)
        testQuotaPresentationFocusesFiveHourWindow(using: harness)
        testHealthToneAggregatesWindows(using: harness)
    }

    /// #64 P5: one pass derives every value the surfaces read, so the formatters no longer
    /// each re-interpret the payload.
    private static func testBalancePresentation(using harness: TestHarness) {
        let balance = BalanceSnapshot(
            providerID: .deepseek,
            totalBalance: Decimal(string: "68.65")!,
            currency: "CNY",
            isAvailable: true,
            grantedBalance: nil,
            toppedUpBalance: nil,
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
