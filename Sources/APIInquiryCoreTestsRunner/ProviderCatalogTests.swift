import APIInquiryCore
import Foundation

enum ProviderCatalogTests {
    static func run(using harness: TestHarness) {
        testDefaultCatalogOrder(using: harness)
        testProviderDescriptorsHaveUniqueStableFields(using: harness)
        testDeepSeekCredentialAccountIsPreserved(using: harness)
        testCodexDescriptorExposesQuotaUsage(using: harness)
        testSnapshotsCanRepresentCodexQuotaUsage(using: harness)
        testSnapshotsCanRepresentZhipuProvider(using: harness)
    }

    private static func testDefaultCatalogOrder(using harness: TestHarness) {
        let catalog = ProviderCatalog.default

        harness.expectEqual(
            catalog.descriptors.map(\.id),
            [.deepseek, .zhipuCodingPlan, .codex],
            "default provider catalog order"
        )
        harness.expectEqual(catalog.defaultProviderID, .deepseek, "default provider id")
    }

    private static func testProviderDescriptorsHaveUniqueStableFields(using harness: TestHarness) {
        let descriptors = ProviderCatalog.default.descriptors

        harness.expectEqual(Set(descriptors.map(\.id)).count, descriptors.count, "provider ids are unique")
        harness.expectEqual(Set(descriptors.map(\.credentialAccount)).count, descriptors.count, "provider credential accounts are unique")
        harness.expectEqual(Set(descriptors.map(\.menuPrefix)).count, descriptors.count, "provider menu prefixes are unique")
        harness.expectTrue(
            descriptors.allSatisfy { !$0.displayName.isEmpty && $0.homepageURL.scheme?.hasPrefix("http") == true },
            "provider descriptors include display names and http homepage urls"
        )
    }

    private static func testDeepSeekCredentialAccountIsPreserved(using harness: TestHarness) {
        let descriptor = ProviderCatalog.default.descriptor(for: .deepseek)

        harness.expectEqual(descriptor?.credentialAccount, "deepseek-api-key", "deepseek keychain account is preserved")
        harness.expectEqual(descriptor?.detailKind, .balance, "deepseek detail kind")
    }

    private static func testCodexDescriptorExposesQuotaUsage(using harness: TestHarness) {
        let descriptor = ProviderCatalog.default.descriptor(for: .codex)

        harness.expectEqual(descriptor?.displayName, "Codex", "codex display name")
        harness.expectEqual(descriptor?.menuPrefix, "GPT", "codex menu prefix")
        harness.expectEqual(descriptor?.credentialAccount, "codex-session-token", "codex keychain account")
        harness.expectEqual(descriptor?.homepageURL, URL(string: "https://chatgpt.com/codex/settings/usage")!, "codex homepage url")
        harness.expectEqual(descriptor?.detailKind, .quotaUsage, "codex detail kind")
    }

    private static func testSnapshotsCanRepresentCodexQuotaUsage(using harness: TestHarness) {
        let snapshot = QuotaUsageSnapshot(
            providerID: .codex,
            planName: "Plus",
            windows: [
                QuotaWindowSnapshot(
                    label: "5h",
                    remainingPercentage: Decimal(72),
                    resetAt: nil,
                    isAvailable: true
                )
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
        )
        let providerSnapshot = ProviderSnapshot.quotaUsage(snapshot)

        harness.expectEqual(snapshot.providerID, .codex, "codex quota provider id")
        harness.expectEqual(providerSnapshot.providerID, .codex, "codex provider snapshot id")
    }

    private static func testSnapshotsCanRepresentZhipuProvider(using harness: TestHarness) {
        let snapshot = makeSnapshot(providerID: .zhipuCodingPlan, total: "0.00")

        harness.expectEqual(snapshot.providerID, .zhipuCodingPlan, "snapshot provider id is configurable")
    }
}
