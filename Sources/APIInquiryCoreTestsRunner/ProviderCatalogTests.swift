import APIInquiryCore
import Foundation

enum ProviderCatalogTests {
    static func run(using harness: TestHarness) {
        testDefaultCatalogOrder(using: harness)
        testProviderDescriptorsHaveUniqueStableFields(using: harness)
        testDeepSeekCredentialAccountIsPreserved(using: harness)
        testSnapshotsCanRepresentZhipuProvider(using: harness)
    }

    private static func testDefaultCatalogOrder(using harness: TestHarness) {
        let catalog = ProviderCatalog.default

        harness.expectEqual(
            catalog.descriptors.map(\.id),
            [.deepseek, .zhipuCodingPlan],
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

    private static func testSnapshotsCanRepresentZhipuProvider(using harness: TestHarness) {
        let snapshot = makeSnapshot(providerID: .zhipuCodingPlan, total: "0.00")

        harness.expectEqual(snapshot.providerID, .zhipuCodingPlan, "snapshot provider id is configurable")
    }
}
