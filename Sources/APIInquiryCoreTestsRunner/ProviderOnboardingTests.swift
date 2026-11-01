import APIInquiryCore
import Foundation

/// The executable half of `docs/provider-onboarding.md`.
///
/// Everything here is checked against `ProviderID.allCases`, so adding a provider makes
/// these assertions run for it immediately. They cover the pieces the compiler cannot:
/// the registry entry, the logo measurement and the localised window labels.
enum ProviderOnboardingTests {
    static func run(using harness: TestHarness) {
        testEveryProviderHasACompleteDescriptor(using: harness)
        testCredentialAccountsAreUnique(using: harness)
        testEveryProviderHasMeasuredLogoMetrics(using: harness)
        testEveryProviderAppearsInFixtureScenarios(using: harness)
        testWindowLabelsExistInBothLanguages(using: harness)
    }

    private static func testEveryProviderHasACompleteDescriptor(using harness: TestHarness) {
        for id in ProviderID.allCases {
            guard let descriptor = BuiltInProviderRegistry.default.registrations
                .first(where: { $0.descriptor.id == id })?
                .descriptor else {
                harness.expectTrue(false, "\(id.rawValue) is registered")
                continue
            }

            harness.expectTrue(!descriptor.displayName.isEmpty, "\(id.rawValue) has a display name")
            harness.expectTrue(!descriptor.menuPrefix.isEmpty, "\(id.rawValue) has a menu prefix")
            harness.expectTrue(!descriptor.credentialAccount.isEmpty, "\(id.rawValue) has a credential account")
            harness.expectTrue(descriptor.homepageURL.host != nil, "\(id.rawValue) has an absolute homepage")
            harness.expectTrue(
                !descriptor.secondaryDisplayName.isEmpty,
                "\(id.rawValue) has a secondary display name"
            )
        }
    }

    private static func testCredentialAccountsAreUnique(using harness: TestHarness) {
        let accounts = BuiltInProviderRegistry.default.registrations.map(\.descriptor.credentialAccount)
        harness.expectEqual(Set(accounts).count, accounts.count, "credential accounts are unique")
    }

    private static func testEveryProviderHasMeasuredLogoMetrics(using harness: TestHarness) {
        for id in ProviderID.allCases {
            for surface in ProviderLogoSurface.allCases {
                guard let template = ProviderLogoMetrics.template(for: id) else {
                    harness.expectTrue(false, "\(id.rawValue) has a logo template")
                    continue
                }

                harness.expectTrue(template.canvasWidth > 0, "\(id.rawValue) canvas width on \(surface)")
                harness.expectTrue(template.canvasHeight > 0, "\(id.rawValue) canvas height on \(surface)")
                harness.expectTrue(template.xHeight > 0, "\(id.rawValue) x-height on \(surface)")
                harness.expectTrue(
                    template.wordmarkHeight >= template.xHeight,
                    "\(id.rawValue) wordmark is at least as tall as its x-height"
                )
                harness.expectTrue(template.visualScale > 0, "\(id.rawValue) visual scale on \(surface)")
            }
        }
    }

    private static func testEveryProviderAppearsInFixtureScenarios(using harness: TestHarness) {
        let scenario = FixtureScenarioData.make(for: .multi)
        harness.expectEqual(
            scenario.registrations.map(\.descriptor.id),
            ProviderID.allCases,
            "fixture scenarios cover every provider"
        )
    }

    private static func testWindowLabelsExistInBothLanguages(using harness: TestHarness) {
        let kinds: [QuotaWindowKind] = [.fiveHour, .week, .month]

        for language in [ResolvedLanguage.zh, .en] {
            let strings = LocalizedStrings(language: language)
            for kind in kinds {
                harness.expectTrue(
                    !strings.quotaWindowLabel(kind).isEmpty,
                    "\(language) window label for \(kind)"
                )
                harness.expectTrue(
                    !strings.quotaWindowHeroLabel(kind).isEmpty,
                    "\(language) hero label for \(kind)"
                )
            }
        }
    }
}
