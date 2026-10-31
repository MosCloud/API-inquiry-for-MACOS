import Foundation

/// Deterministic states for a development copy, so UI work can be checked without
/// touching the Keychain or waiting for a real provider to fail.
///
/// Fixtures only wire the credential and provider boundary; the coordinator, view
/// models and views stay real. Activation is guarded in the app: `DEBUG` builds that
/// carry a git commit and are launched with `--fixtures <scenario>`.
public enum FixtureScenario: String, CaseIterable, Sendable {
    case stale
    case failed
    case loading
    case multi
}

public enum FixtureMode {
    public static func scenario(from arguments: [String]) -> FixtureScenario? {
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            if argument == "--fixtures" {
                guard let value = iterator.next() else { return nil }
                return FixtureScenario(rawValue: value)
            }

            if argument.hasPrefix("--fixtures=") {
                let value = String(argument.dropFirst("--fixtures=".count))
                return FixtureScenario(rawValue: value)
            }
        }

        return nil
    }
}

public final class FixtureBalanceProvider: BalanceProvider {
    public enum Behavior {
        /// Succeeds once, then fails like an offline refresh — the state behind the stale marker.
        case succeedsThenFails(ProviderSnapshot)
        case alwaysFails(BalanceProviderError)
        /// Never finishes, keeping the provider in `.loading`.
        case suspends
    }

    public let id: ProviderID
    private let behavior: Behavior
    private var attempts = 0
    private let lock = NSLock()

    public init(id: ProviderID, behavior: Behavior) {
        self.id = id
        self.behavior = behavior
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        switch behavior {
        case .succeedsThenFails(let snapshot):
            lock.lock()
            attempts += 1
            let attempt = attempts
            lock.unlock()

            if attempt == 1 {
                return snapshot
            }
            throw URLError(.notConnectedToInternet)

        case .alwaysFails(let error):
            throw error

        case .suspends:
            try await Task.sleep(nanoseconds: 3_600 * 1_000_000_000)
            throw BalanceProviderError.decodingFailed
        }
    }
}

public struct FixtureScenarioData {
    public let registrations: [ProviderRegistration]
    public let credentialStore: CredentialStore
    public let preferences: ProviderPreferencesStore
    public let defaultProviderID: ProviderID

    public static func make(for scenario: FixtureScenario, now: Date = Date()) -> FixtureScenarioData {
        switch scenario {
        case .stale:
            return single(.deepseek, behavior: .succeedsThenFails(balance(now: now)), now: now)
        case .failed:
            return single(.deepseek, behavior: .alwaysFails(.authenticationFailed), now: now)
        case .loading:
            return single(.deepseek, behavior: .suspends, now: now)
        case .multi:
            let deepSeek = registration(.deepseek, .succeedsThenFails(balance(now: now)))
            let zhipu = registration(.zhipuCodingPlan, .succeedsThenFails(planUsage(now: now)))
            let codex = registration(.codex, .succeedsThenFails(codexQuota(now: now)))
            let openCode = registration(.opencode, .succeedsThenFails(openCodeQuota(now: now)))
            let ids: [ProviderID] = [.deepseek, .zhipuCodingPlan, .codex, .opencode]

            return FixtureScenarioData(
                registrations: [deepSeek, zhipu, codex, openCode],
                credentialStore: InMemoryCredentialStore(credentialsByAccount: credentials(for: ids)),
                preferences: InMemoryProviderPreferencesStore(addedProviderIDs: ids, primaryProviderID: .opencode),
                defaultProviderID: .opencode
            )
        }
    }

    private static func single(
        _ id: ProviderID,
        behavior: FixtureBalanceProvider.Behavior,
        now: Date
    ) -> FixtureScenarioData {
        FixtureScenarioData(
            registrations: [registration(id, behavior)],
            credentialStore: InMemoryCredentialStore(credentialsByAccount: credentials(for: [id])),
            preferences: InMemoryProviderPreferencesStore(addedProviderIDs: [id], primaryProviderID: id),
            defaultProviderID: id
        )
    }

    private static func registration(
        _ id: ProviderID,
        _ behavior: FixtureBalanceProvider.Behavior
    ) -> ProviderRegistration {
        let provider = FixtureBalanceProvider(id: id, behavior: behavior)
        return ProviderRegistration(descriptor: descriptor(for: id)) { provider }
    }

    private static func descriptor(for id: ProviderID) -> ProviderDescriptor {
        guard let descriptor = BuiltInProviderRegistry.default.registrations
            .first(where: { $0.descriptor.id == id })?
            .descriptor else {
            preconditionFailure("Missing built-in descriptor for \(id.rawValue)")
        }
        return descriptor
    }

    private static func credentials(for ids: [ProviderID]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ids.map { (descriptor(for: $0).credentialAccount, "fixture-key") })
    }

    private static func balance(now: Date) -> ProviderSnapshot {
        .balance(BalanceSnapshot(
            providerID: .deepseek,
            totalBalance: Decimal(string: "68.65")!,
            currency: "CNY",
            isAvailable: true,
            grantedBalance: nil,
            toppedUpBalance: nil,
            fetchedAt: now
        ))
    }

    private static func planUsage(now: Date) -> ProviderSnapshot {
        .planUsage(PlanUsageSnapshot(
            providerID: .zhipuCodingPlan,
            windowLabel: "5h",
            windowKind: .fiveHour,
            usagePercentage: Decimal(17),
            resetAt: now.addingTimeInterval(3_600),
            isAvailable: true,
            fetchedAt: now
        ))
    }

    private static func codexQuota(now: Date) -> ProviderSnapshot {
        .quotaUsage(QuotaUsageSnapshot(
            providerID: .codex,
            planName: "ChatGPT",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(72), resetAt: now.addingTimeInterval(3_600), isAvailable: true),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(88), resetAt: now.addingTimeInterval(86_400 * 5), isAvailable: true)
            ],
            fetchedAt: now
        ))
    }

    private static func openCodeQuota(now: Date) -> ProviderSnapshot {
        .quotaUsage(QuotaUsageSnapshot(
            providerID: .opencode,
            planName: "OpenCode Go",
            windows: [
                QuotaWindowSnapshot(label: "5h", kind: .fiveHour, remainingPercentage: Decimal(100), resetAt: now.addingTimeInterval(3_600), isAvailable: true),
                QuotaWindowSnapshot(label: "Week", kind: .week, remainingPercentage: Decimal(90), resetAt: now.addingTimeInterval(86_400 * 5), isAvailable: true),
                QuotaWindowSnapshot(label: "Month", kind: .month, remainingPercentage: Decimal(95), resetAt: now.addingTimeInterval(86_400 * 25), isAvailable: true)
            ],
            fetchedAt: now
        ))
    }
}
