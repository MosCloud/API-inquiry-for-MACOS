import Foundation

/// Reads the OpenCode Go subscription allowance from the OpenCode Console API.
///
/// `GET https://opencode.ai/zen/go/v1/usage` returns the three rolling windows that
/// OpenCode Go applies per model: a 5-hour window (20% of the monthly allowance),
/// a weekly window (50%) and the monthly window (100%). Each meter reports how much
/// of *that* window has been used, so the snapshot stores the remaining percentage.
public final class OpenCodeGoUsageProvider: BalanceProvider {
    public static let defaultUsageURL = URL(string: "https://opencode.ai/zen/go/v1/usage")!
    /// The endpoint sits behind Cloudflare, which rejects requests that identify as a
    /// generic HTTP library, so the provider always sends a dedicated user agent.
    ///
    /// The token is deliberately stable: tying it to the release version meant it drifted
    /// from `Scripts/version.env` and had to be edited on every bump (#44).
    public static let defaultUserAgent = "API-Inquiry/1.0"

    public let id: ProviderID = .opencode

    private let usageURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date
    private let userAgent: String

    public init(
        usageURL: URL = OpenCodeGoUsageProvider.defaultUsageURL,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init,
        userAgent: String = OpenCodeGoUsageProvider.defaultUserAgent
    ) {
        self.usageURL = usageURL
        self.httpClient = httpClient
        self.now = now
        self.userAgent = userAgent
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        let credential = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            throw BalanceProviderError.authenticationFailed
        }

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return .quotaUsage(try decodeUsage(from: response.data))
        case 401:
            throw BalanceProviderError.authenticationFailed
        case 403:
            // The OpenCode Go endpoint answers 403 when the credential has no
            // subscription (the CLI treats it the same way).
            throw BalanceProviderError.subscriptionRequired
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeUsage(from data: Data) throws -> QuotaUsageSnapshot {
        let payload: OpenCodeUsageEnvelope
        do {
            payload = try JSONDecoder().decode(OpenCodeUsageEnvelope.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        return QuotaUsageSnapshot(
            providerID: id,
            planName: "OpenCode Go",
            windows: [
                makeWindow(label: "5h", kind: .fiveHour, meter: payload.usage.rolling),
                makeWindow(label: "Week", kind: .week, meter: payload.usage.weekly),
                makeWindow(label: "Month", kind: .month, meter: payload.usage.monthly)
            ],
            fetchedAt: now()
        )
    }

    private func makeWindow(label: String, kind: QuotaWindowKind, meter: OpenCodeUsageMeter) -> QuotaWindowSnapshot {
        let remaining = clamp(Decimal(100) - meter.percent, lower: 0, upper: 100)
        return QuotaWindowSnapshot(
            label: label,
            kind: kind,
            remainingPercentage: remaining,
            resetAt: meter.resetsAt,
            isAvailable: !meter.isRateLimited && remaining > 0
        )
    }

    private func clamp(_ value: Decimal, lower: Decimal, upper: Decimal) -> Decimal {
        min(max(value, lower), upper)
    }
}

private struct OpenCodeUsageEnvelope: Decodable {
    let usage: OpenCodeUsageWindows
}

private struct OpenCodeUsageWindows: Decodable {
    let rolling: OpenCodeUsageMeter
    let weekly: OpenCodeUsageMeter
    let monthly: OpenCodeUsageMeter
}

private struct OpenCodeUsageMeter: Decodable {
    let status: String
    let percent: Decimal
    let resetsAt: Date?

    var isRateLimited: Bool {
        status.caseInsensitiveCompare("rate-limited") == .orderedSame
    }

    enum CodingKeys: String, CodingKey {
        case status
        case percent
        case resetsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? container.decode(String.self, forKey: .status)) ?? "ok"
        percent = try Self.decodePercent(from: container)
        resetsAt = Self.decodeResetDate(from: container)
    }

    private static func decodePercent(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Decimal {
        if let decimalValue = try? container.decode(Decimal.self, forKey: .percent) {
            return decimalValue
        }
        if let doubleValue = try? container.decode(Double.self, forKey: .percent) {
            return Decimal(doubleValue)
        }
        if let stringValue = try? container.decode(String.self, forKey: .percent),
           let decimalValue = Decimal(string: stringValue, locale: Locale(identifier: "en_US_POSIX")) {
            return decimalValue
        }
        throw DecodingError.dataCorruptedError(
            forKey: .percent,
            in: container,
            debugDescription: "Expected the used percentage as a number or decimal string."
        )
    }

    private static func decodeResetDate(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Date? {
        guard let rawValue = try? container.decode(String.self, forKey: .resetsAt) else {
            return nil
        }
        for formatter in Self.iso8601Formatters {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }
        return nil
    }

    private static var iso8601Formatters: [ISO8601DateFormatter] {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        return [fractional, standard]
    }
}
