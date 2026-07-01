import Foundation

public struct CodexCredential: Equatable {
    public let accessToken: String
    public let accountID: String?

    public init(accessToken: String, accountID: String?) {
        self.accessToken = accessToken
        self.accountID = accountID
    }
}

public enum CodexCredentialParser {
    public static func parse(_ value: String) throws -> CodexCredential {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }

        if trimmed.hasPrefix("{") {
            return try parseAuthJSON(trimmed)
        }

        let token = normalizedAccessToken(trimmed)
        guard !token.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }

        return CodexCredential(accessToken: token, accountID: nil)
    }

    private static func parseAuthJSON(_ value: String) throws -> CodexCredential {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BalanceProviderError.authenticationFailed
        }

        let tokens = object["tokens"] as? [String: Any]
        let accessToken = firstNonEmptyAccessToken([
            tokens?["access_token"],
            object["accessToken"],
            object["access_token"]
        ])
        let accountID = firstNonEmptyString([
            tokens?["account_id"],
            object["account_id"],
            object["accountID"]
        ])

        guard let accessToken else {
            throw BalanceProviderError.authenticationFailed
        }

        return CodexCredential(accessToken: accessToken, accountID: accountID)
    }

    private static func firstNonEmptyString(_ values: [Any?]) -> String? {
        values
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func firstNonEmptyAccessToken(_ values: [Any?]) -> String? {
        values
            .compactMap { $0 as? String }
            .map(normalizedAccessToken)
            .first { !$0.isEmpty }
    }

    private static func normalizedAccessToken(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased == "bearer" {
            return ""
        }
        if lowercased.hasPrefix("bearer ") {
            return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
