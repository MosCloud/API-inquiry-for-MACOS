import APIInquiryCore
import Foundation

/// Zhipu is a single-window provider: its plan snapshot is the same shape as any other
/// quota snapshot, so fixtures build it the same way instead of through a second type.
enum QuotaTestFixtures {
    static func zhipu(
        usedPercentage: Decimal = Decimal(17),
        resetAt: Date? = nil,
        fetchedAt: Date = Date(timeIntervalSince1970: 1_715_000_000)
    ) -> QuotaUsageSnapshot {
        QuotaUsageSnapshot(
            providerID: .zhipuCodingPlan,
            planName: "GLM Coding Plan",
            windows: [
                QuotaWindowSnapshot(
                    label: "5h",
                    kind: .fiveHour,
                    remainingPercentage: min(max(Decimal(100) - usedPercentage, Decimal(0)), Decimal(100)),
                    resetAt: resetAt,
                    isAvailable: usedPercentage < Decimal(100)
                )
            ],
            fetchedAt: fetchedAt
        )
    }
}
