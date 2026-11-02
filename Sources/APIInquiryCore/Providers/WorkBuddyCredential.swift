import Foundation

/// The credential a WorkBuddy request needs, in the shape it travels through
/// `CredentialStore`.
///
/// `BalanceProvider.fetchSnapshot(apiKey:)` carries a single string, so multi-field
/// credentials travel as JSON — the same convention `CodexCredentialParser` uses. The
/// fields are all required because the billing endpoint rejects a request that omits
/// them: `X-User-Id` and `X-Domain` select the account, and a token alone answers 200
/// with an empty account list, which reads as "you have no credits".
public struct WorkBuddyCredential: Equatable {
    public let accessToken: String
    public let userID: String
    public let domain: String
    /// The region base the credential's sign-in belongs to. Derived from `domain`.
    public let billingBase: URL

    public init(accessToken: String, userID: String, domain: String) {
        self.accessToken = accessToken
        self.userID = userID
        self.domain = domain
        self.billingBase = WorkBuddyCredential.billingBase(forDomain: domain)
    }

    /// The CN billing base, matching the desktop app's own domestic gateway.
    public static let chinaBillingBase = URL(string: "https://www.codebuddy.cn")!

    /// The international base. Parsed but not yet supported end to end — see
    /// `WorkBuddyCredentialParser.parse` for why the distinction matters.
    public static let globalBillingBase = URL(string: "https://www.workbuddy.ai")!

    /// Resolve the billing base for a credential's sign-in domain.
    ///
    /// A token issued at one domain is refused by the other, so the choice cannot be
    /// deferred to a fallback: it must come from the credential itself.
    public static func billingBase(forDomain domain: String) -> URL {
        let normalized = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasSuffix("workbuddy.ai") ? globalBillingBase : chinaBillingBase
    }

    /// Whether this credential belongs to the region v0.4.1 supports.
    public var isChinaRegion: Bool {
        billingBase == WorkBuddyCredential.chinaBillingBase
    }
}

/// Builds a `WorkBuddyCredential` from the JSON the credential store hands the provider.
public enum WorkBuddyCredentialParser {
    /// Parse the serialized credential.
    ///
    /// Only the CN region is accepted in v0.4.1. The international product signs in
    /// through a different base, answers with a different model catalogue and bills
    /// separately; shipping it half-wired would show an empty balance rather than an
    /// honest "not supported yet", so it is refused explicitly.
    public static func parse(_ value: String) throws -> WorkBuddyCredential {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = nonEmpty(object["accessToken"] as? String) else {
            throw BalanceProviderError.authenticationFailed
        }

        let domain = nonEmpty(object["domain"] as? String) ?? "www.workbuddy.cn"
        let credential = WorkBuddyCredential(
            accessToken: accessToken,
            userID: nonEmpty(object["uid"] as? String) ?? "",
            domain: domain
        )

        guard credential.isChinaRegion else {
            throw BalanceProviderError.subscriptionRequired
        }
        return credential
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
