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
        let credential = try CodexCredentialParser.parse(apiKey)
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credential.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return .quotaUsage(try decodeUsage(from: response.data))
        case 401, 403:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeUsage(from data: Data) throws -> QuotaUsageSnapshot {
        let payload: CodexUsagePayload
        do {
            payload = try JSONDecoder().decode(CodexUsageEnvelope.self, from: data).payload
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        var windows: [QuotaWindowSnapshot] = []
        if let primary = payload.rateLimit.primaryWindow {
            windows.append(makeWindow(label: "5h", from: primary))
        }
        if let secondary = payload.rateLimit.secondaryWindow {
            windows.append(makeWindow(label: "Week", from: secondary))
        }

        guard !windows.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return QuotaUsageSnapshot(
            providerID: id,
            planName: normalizedPlanName(payload.planType),
            windows: windows,
            fetchedAt: now()
        )
    }

    private func makeWindow(label: String, from window: CodexRateLimitWindow) -> QuotaWindowSnapshot {
        let remaining = clamp(Decimal(100) - Decimal(window.usedPercent), lower: 0, upper: 100)
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
    let usedPercent: Int
    let resetAt: Int?
    let resetAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAt = "reset_at"
        case resetAfterSeconds = "reset_after_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeFlexibleInt(forKey: .usedPercent)
        resetAt = try container.decodeFlexibleOptionalInt(forKey: .resetAt)
        resetAfterSeconds = try container.decodeFlexibleOptionalInt(forKey: .resetAfterSeconds)
    }
}

private extension KeyedDecodingContainer {
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
