import APIInquiryCore
import Foundation

enum FixtureModeTests {
    @MainActor
    static func run(using harness: TestHarness) async {
        testScenarioParsing(using: harness)
        await testStaleProviderSucceedsThenFails(using: harness)
        await testFailedProviderThrows(using: harness)
        testScenarioData(using: harness)
    }

    private static func testScenarioParsing(using harness: TestHarness) {
        harness.expectEqual(
            FixtureMode.scenario(from: ["APIInquiry", "--fixtures", "stale"]),
            .stale,
            "space-separated fixture argument"
        )
        harness.expectEqual(
            FixtureMode.scenario(from: ["APIInquiry", "--fixtures=failed"]),
            .failed,
            "equals-separated fixture argument"
        )
        harness.expectEqual(
            FixtureMode.scenario(from: ["APIInquiry", "--fixtures", "unknown"]),
            nil,
            "unknown fixture name is ignored"
        )
        harness.expectEqual(
            FixtureMode.scenario(from: ["APIInquiry"]),
            nil,
            "no fixture argument"
        )
        harness.expectEqual(
            FixtureMode.scenario(from: ["APIInquiry", "--fixtures"]),
            nil,
            "missing fixture value is ignored"
        )
    }

    private static func testStaleProviderSucceedsThenFails(using harness: TestHarness) async {
        let provider = FixtureBalanceProvider(
            id: .deepseek,
            behavior: .succeedsThenFails(FixtureSnapshot.balance)
        )

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "fixture")
            harness.expectTrue(snapshot == FixtureSnapshot.balance, "first fixture fetch succeeds")
        } catch {
            harness.expectTrue(false, "first fixture fetch should succeed")
        }

        do {
            _ = try await provider.fetchSnapshot(apiKey: "fixture")
            harness.expectTrue(false, "second fixture fetch should fail")
        } catch {
            harness.expectTrue(true, "second fixture fetch fails")
        }
    }

    private static func testFailedProviderThrows(using harness: TestHarness) async {
        let provider = FixtureBalanceProvider(id: .deepseek, behavior: .alwaysFails(.authenticationFailed))

        do {
            _ = try await provider.fetchSnapshot(apiKey: "fixture")
            harness.expectTrue(false, "alwaysFails should throw")
        } catch {
            harness.expectTrue(error is BalanceProviderError, "alwaysFails throws a provider error")
        }
    }

    @MainActor
    private static func testScenarioData(using harness: TestHarness) {
        let stale = FixtureScenarioData.make(for: .stale)
        harness.expectEqual(stale.registrations.count, 1, "stale has one provider")
        harness.expectEqual(stale.defaultProviderID, .deepseek, "stale defaults to deepseek")
        harness.expectTrue(
            stale.credentialStore is InMemoryCredentialStore,
            "fixtures never touch the keychain"
        )

        let multi = FixtureScenarioData.make(for: .multi)
        harness.expectEqual(multi.registrations.map(\.descriptor.id), [.deepseek, .zhipuCodingPlan, .codex, .opencode], "multi provider order")
        harness.expectEqual(multi.defaultProviderID, .opencode, "multi defaults to opencode")
        harness.expectTrue(
            multi.preferences.addedProviderIDs.contains(.opencode),
            "multi adds opencode"
        )

        harness.expectEqual(FixtureScenarioData.make(for: .failed).registrations.count, 1, "failed has one provider")
        harness.expectEqual(FixtureScenarioData.make(for: .loading).registrations.count, 1, "loading has one provider")
    }
}

private enum FixtureSnapshot {
    static let balance = ProviderSnapshot.balance(BalanceSnapshot(
        providerID: .deepseek,
        totalBalance: Decimal(string: "68.65")!,
        currency: "CNY",
        isAvailable: true,
        grantedBalance: nil,
        toppedUpBalance: nil,
        fetchedAt: Date(timeIntervalSince1970: 1_715_000_000)
    ))
}
