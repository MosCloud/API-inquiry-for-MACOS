import Foundation

/// Reads the Antigravity quota summary from the local language server.
///
/// `RetrieveUserQuotaSummary` answers with model *groups*, each holding the windows that apply
/// to that group. This provider deliberately reads one group:
///
/// - **Gemini Models** carries a weekly bucket with both a remaining fraction and a reset
///   time, which is everything the panel needs.
/// - **Claude and GPT models** carries a weekly and a five-hour bucket whose reset time is
///   not provided at all (the key is absent, not empty), so showing them today would add two
///   rows that cannot say when they refill.
///
/// The group is matched by its display name rather than by hard-coding bucket ids: a paid
/// account's Gemini group carries an extra `gemini-5h` bucket, and iterating whatever the
/// group holds covers it without a code change.
public final class AntigravityQuotaProvider: BalanceProvider {
    public let id: ProviderID = .antigravity

    /// The one group this version reports.
    static let geminiGroupName = "Gemini Models"

    private let httpClient: HTTPClient
    private let now: () -> Date
    private let sessionReader: AntigravitySessionReader

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init,
        sessionReader: AntigravitySessionReader = AntigravitySessionReader()
    ) {
        self.httpClient = httpClient
        self.now = now
        self.sessionReader = sessionReader
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        let session = try sessionForFetch(payload: apiKey)

        guard var components = session.baseURL else {
            throw BalanceProviderError.invalidURL
        }
        components.append(path: "exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary")

        var request = URLRequest(url: components)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(session.csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
        request.httpBody = Data("{}".utf8)

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return .quotaUsage(try decodeSummary(from: response.data))
        case 401, 403:
            // The server is up and refused: the user is signed out, which they can fix in
            // Antigravity. This is not "replace the key" — there is no key.
            throw AntigravitySessionError.notSignedIn
        case 404:
            // The RPC path is gone, so Antigravity changed shape under us.
            throw AntigravitySessionError.versionChanged
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    /// Prefers the session encoded in the credential slot, and falls back to reading the
    /// daemon file.
    ///
    /// The fallback matters when the credential chain is not in play — a direct call, or a
    /// future surface that asks the provider for a snapshot without a store behind it.
    private func sessionForFetch(payload: String) throws -> AntigravityLocalSession {
        if let session = try? AntigravitySessionPayload.decode(payload) {
            return session
        }
        return try sessionReader.readSession()
    }

    private func decodeSummary(from data: Data) throws -> QuotaUsageSnapshot {
        let payload: AntigravityQuotaSummaryPayload
        do {
            payload = try JSONDecoder().decode(AntigravityQuotaSummaryPayload.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        let groups = payload.response.groups ?? []
        guard let geminiGroup = groups.first(where: { $0.displayName == Self.geminiGroupName }) else {
            throw BalanceProviderError.missingBalanceInfo
        }

        let windows = (geminiGroup.buckets ?? []).compactMap(makeWindow)
        guard !windows.isEmpty else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return QuotaUsageSnapshot(
            providerID: id,
            planName: "Antigravity",
            windows: windows,
            fetchedAt: now()
        )
    }

    /// One bucket becomes one window, using this codebase's canonical labels.
    ///
    /// The API names windows `"weekly"` and `"5h"`. `QuotaWindowKind(label:)` accepts `"Week"`
    /// and `"5h"`, so weekly has to be normalised here — passing `"weekly"` through would leave
    /// the English word in the Chinese UI, and changing that shared mapping would touch Codex.
    private func makeWindow(_ bucket: AntigravityQuotaBucketPayload) -> QuotaWindowSnapshot? {
        guard let kind = windowKind(for: bucket.window) else {
            return nil
        }
        guard let remainingFraction = bucket.remainingFraction else {
            return nil
        }

        let remaining = clamp(Decimal(remainingFraction) * 100, lower: 0, upper: 100)
        return QuotaWindowSnapshot(
            label: kind == .fiveHour ? "5h" : "Week",
            kind: kind,
            remainingPercentage: remaining,
            resetAt: bucket.resetTime.flatMap(Self.parseDate),
            isAvailable: remaining > 0
        )
    }

    /// A window cadence this version does not recognise is skipped, not guessed.
    ///
    /// The plan's scope is the weekly bucket; mapping an unknown cadence onto a known window
    /// would put a number under the wrong label.
    private func windowKind(for rawValue: String?) -> QuotaWindowKind? {
        switch rawValue {
        case "weekly":
            return .week
        case "5h":
            return .fiveHour
        default:
            return nil
        }
    }

    private func clamp(_ value: Decimal, lower: Decimal, upper: Decimal) -> Decimal {
        min(max(value, lower), upper)
    }

    static func parseDate(_ rawValue: String) -> Date? {
        for formatter in iso8601Formatters {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }
        return nil
    }

    private static var iso8601Formatters: [ISO8601DateFormatter] {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [fractional, standard]
    }
}

// MARK: - Wire types

private struct AntigravityQuotaSummaryPayload: Decodable {
    let response: AntigravityQuotaSummaryResponse
}

private struct AntigravityQuotaSummaryResponse: Decodable {
    let groups: [AntigravityQuotaGroupPayload]?
}

private struct AntigravityQuotaGroupPayload: Decodable {
    let displayName: String?
    let buckets: [AntigravityQuotaBucketPayload]?
}

private struct AntigravityQuotaBucketPayload: Decodable {
    let bucketId: String?
    let window: String?
    let remainingFraction: Double?
    let resetTime: String?

    enum CodingKeys: String, CodingKey {
        case bucketId
        case window
        case remainingFraction
        case resetTime
    }
}
