import Foundation

public struct CodexManualResetCredit: Equatable {
    public let grantedAt: Date?
    public let expiresAt: Date?
    public let redeemedAt: Date?

    public init(grantedAt: Date?, expiresAt: Date?, redeemedAt: Date?) {
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.redeemedAt = redeemedAt
    }
}

public struct CodexManualResetCreditsSnapshot: Equatable {
    public let credits: [CodexManualResetCredit]
    public let fetchedAt: Date

    public init(credits: [CodexManualResetCredit], fetchedAt: Date) {
        self.credits = credits
        self.fetchedAt = fetchedAt
    }
}

public final class CodexManualResetCreditsProvider {
    private let creditsURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date

    public init(
        creditsURL: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.creditsURL = creditsURL
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchSnapshot(apiKey: String) async throws -> CodexManualResetCreditsSnapshot {
        let credential = try CodexCredentialParser.parse(apiKey)
        var request = URLRequest(url: creditsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credential.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return try decodeSnapshot(from: response.data)
        case 401, 403:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeSnapshot(from data: Data) throws -> CodexManualResetCreditsSnapshot {
        let payload: CodexManualResetCreditsPayload
        do {
            payload = try JSONDecoder().decode(CodexManualResetCreditsPayload.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        guard let credits = payload.credits else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return CodexManualResetCreditsSnapshot(credits: credits, fetchedAt: now())
    }
}

private struct CodexManualResetCreditsPayload: Decodable {
    let credits: [CodexManualResetCredit]?

    enum CodingKeys: String, CodingKey {
        case credits
        case payload
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let credits = try container.decodeIfPresent([CodexManualResetCredit].self, forKey: .credits) {
            self.credits = credits
            return
        }
        if let nested = try container.decodeIfPresent(CodexManualResetCreditsPayload.self, forKey: .payload) {
            credits = nested.credits
            return
        }
        if let nested = try container.decodeIfPresent(CodexManualResetCreditsPayload.self, forKey: .data) {
            credits = nested.credits
            return
        }
        credits = nil
    }
}

private struct CodexManualResetCreditPayload: Decodable {
    let grantedAt: Date?
    let expiresAt: Date?
    let redeemedAt: Date?

    enum CodingKeys: String, CodingKey {
        case grantedAt = "granted_at"
        case expiresAt = "expires_at"
        case redeemedAt = "redeemed_at"
    }
}

extension CodexManualResetCredit: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodexManualResetCreditPayload.CodingKeys.self)
        grantedAt = try container.decodeFlexibleISO8601Date(forKey: .grantedAt)
        expiresAt = try container.decodeFlexibleISO8601Date(forKey: .expiresAt)
        redeemedAt = try container.decodeFlexibleISO8601Date(forKey: .redeemedAt)
    }
}

private extension KeyedDecodingContainer where Key == CodexManualResetCreditPayload.CodingKeys {
    func decodeFlexibleISO8601Date(forKey key: Key) throws -> Date? {
        guard contains(key) else {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }

        let rawValue = try decode(String.self, forKey: key)
        for formatter in Self.iso8601Formatters {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected an ISO-8601 date string."
        )
    }

    static var iso8601Formatters: [ISO8601DateFormatter] {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [fractional, standard]
    }
}
