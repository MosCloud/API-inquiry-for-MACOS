import Foundation

public final class CodexQuotaProvider: BalanceProvider {
    public let id: ProviderID = .codex

    private let usageURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date

    public init(
        usageURL: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.usageURL = usageURL
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        let credential = try parseCredential(apiKey)
        let request = usageRequest(for: credential)

        do {
            return .quotaUsage(try await fetchUsage(with: request))
        } catch BalanceProviderError.missingBalanceInfo {
            return .quotaUsage(try await fetchUsage(with: request))
        }
    }

    private func usageRequest(for credential: CodexCredential) -> URLRequest {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credential.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        return request
    }

    private func fetchUsage(with request: URLRequest) async throws -> QuotaUsageSnapshot {
        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return try decodeUsage(from: response.data)
        case 401, 403:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func parseCredential(_ value: String) throws -> CodexCredential {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }

        if trimmed.hasPrefix("{") {
            return try parseAuthJSON(trimmed)
        }

        let token: String
        if trimmed.lowercased().hasPrefix("bearer ") {
            token = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            token = trimmed
        }

        guard !token.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }
        return CodexCredential(accessToken: token, accountID: nil)
    }

    private func parseAuthJSON(_ value: String) throws -> CodexCredential {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BalanceProviderError.authenticationFailed
        }

        let tokens = object["tokens"] as? [String: Any]
        let accessToken = firstNonEmptyString([
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

    private func firstNonEmptyString(_ values: [Any?]) -> String? {
        values
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func decodeUsage(from data: Data) throws -> QuotaUsageSnapshot {
        let payload: CodexUsagePayload
        do {
            payload = try JSONDecoder().decode(CodexUsageEnvelope.self, from: data).payload
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        guard let primary = payload.rateLimit.primaryWindow,
              let secondary = payload.rateLimit.secondaryWindow else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return QuotaUsageSnapshot(
            providerID: id,
            planName: normalizedPlanName(payload.planType),
            windows: [
                makeWindow(label: "5h", from: primary),
                makeWindow(label: "Week", from: secondary)
            ],
            fetchedAt: now()
        )
    }

    private func makeWindow(label: String, from window: CodexRateLimitWindow) -> QuotaWindowSnapshot {
        let remaining = clamp(Decimal(100) - window.usedPercent, lower: 0, upper: 100)
        return QuotaWindowSnapshot(
            label: label,
            remainingPercentage: remaining,
            resetAt: resetDate(for: window),
            isAvailable: remaining > 0
        )
    }

    private func resetDate(for window: CodexRateLimitWindow) -> Date? {
        if let resetAt = window.resetAt {
            return Date(timeIntervalSince1970: TimeInterval(resetAt))
        }
        if let resetAfterSeconds = window.resetAfterSeconds {
            return Date(timeInterval: TimeInterval(resetAfterSeconds), since: now())
        }
        return nil
    }

    private func clamp(_ value: Decimal, lower: Decimal, upper: Decimal) -> Decimal {
        min(max(value, lower), upper)
    }

    private func normalizedPlanName(_ rawValue: String?) -> String {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return "Unknown"
        }

        let normalized = rawValue.lowercased()
        if normalized.contains("20x") {
            return "Pro 20x"
        }
        if normalized.contains("5x") {
            return "Pro 5x"
        }
        if normalized == "free" {
            return "Free"
        }
        if normalized == "plus" {
            return "Plus"
        }
        if normalized == "pro" || normalized.contains("pro_lite") {
            return "Pro"
        }
        if normalized.contains("business") || normalized == "team" || normalized.contains("self_serve") {
            return "Business"
        }
        if normalized.contains("enterprise") || normalized == "edu" || normalized == "education" {
            return "Enterprise/Edu"
        }

        return rawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private struct CodexCredential {
    let accessToken: String
    let accountID: String?
}

private struct CodexUsageEnvelope: Decodable {
    let payload: CodexUsagePayload

    enum CodingKeys: String, CodingKey {
        case usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let usage = try container.decodeIfPresent(CodexUsagePayload.self, forKey: .usage) {
            payload = usage
        } else {
            payload = try CodexUsagePayload(from: decoder)
        }
    }
}

private struct CodexUsagePayload: Decodable {
    let planType: String?
    let rateLimit: CodexRateLimit

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
    }
}

private struct CodexRateLimit: Decodable {
    let primaryWindow: CodexRateLimitWindow?
    let secondaryWindow: CodexRateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct CodexRateLimitWindow: Decodable {
    let usedPercent: Decimal
    let resetAt: Int?
    let resetAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAt = "reset_at"
        case resetAfterSeconds = "reset_after_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeFlexibleDecimal(forKey: .usedPercent)
        resetAt = try container.decodeFlexibleOptionalInt(forKey: .resetAt)
        resetAfterSeconds = try container.decodeFlexibleOptionalInt(forKey: .resetAfterSeconds)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDecimal(forKey key: Key) throws -> Decimal {
        if let decimalValue = try? decode(Decimal.self, forKey: key) {
            return decimalValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        let stringValue = try decode(String.self, forKey: key)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimalValue = Decimal(string: stringValue, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected a decimal number, number string, or integer string."
            )
        }
        return decimalValue
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        let stringValue = try decode(String.self, forKey: key)
        guard let intValue = Int(stringValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected an integer, number, or integer string."
            )
        }
        return intValue
    }

    func decodeFlexibleOptionalInt(forKey key: Key) throws -> Int? {
        guard contains(key) else {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        return try decodeFlexibleInt(forKey: key)
    }
}
