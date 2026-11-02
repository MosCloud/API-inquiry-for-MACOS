import Foundation

/// Reads WorkBuddy's remaining credit balance.
///
/// WorkBuddy sells *credits*, not currency and not a percentage: the billing endpoint
/// answers with a list of packages, each carrying how much of its own allowance is
/// left. `CapacityType` separates the two kinds that matter — 4 is a monthly package
/// (refreshes at the cycle end) and anything else is a one-off grant (expires for
/// good). The snapshot therefore reports the sum, with the one-off grants as the
/// "granted" portion, and the soonest expiry so the panel can warn before credits
/// lapse.
///
/// The endpoint is read-only. This provider never claims, signs in, or writes
/// anything back.
public final class WorkBuddyBalanceProvider: BalanceProvider {
    /// The billing endpoint, shared by both regions.
    public static let resourcePath = "/v2/billing/meter/get-user-resource"

    /// The product code WorkBuddy's own client asks for. A different code answers 200
    /// with an empty account list rather than an error.
    public static let productCode = "p_tcaca"

    /// The currency code this provider reports. Credits are not money; the formatter
    /// renders this as a localised unit rather than a currency symbol.
    public static let creditCurrency = "CREDITS"

    public let id: ProviderID = .workbuddy

    private let httpClient: HTTPClient
    private let now: () -> Date
    private let session: URLSession?

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.now = now
        self.session = nil
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        let credential = try WorkBuddyCredentialParser.parse(apiKey)

        var request = URLRequest(url: credential.billingBase.appendingPathComponent(Self.resourcePath))
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !credential.userID.isEmpty {
            request.setValue(credential.userID, forHTTPHeaderField: "X-User-Id")
        }
        request.setValue(credential.domain, forHTTPHeaderField: "X-Domain")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(now: now()))

        let response: HTTPResponse
        do {
            response = try await httpClient.data(for: request)
        } catch {
            throw BalanceProviderError.serverError(statusCode: 0)
        }

        switch response.statusCode {
        case 200:
            return .balance(try decodeSnapshot(from: response.data, credential: credential))
        case 401, 403:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    /// How far ahead the package window reaches, in seconds.
    ///
    /// The upstream's own client sends `3185136e6` **milliseconds**, which is
    /// 3,185,136,000 seconds — a deliberately absurd horizon (~100 years) that means "no
    /// upper bound". Getting this wrong is silent rather than loud: a plausible-looking
    /// 36.9-day window still answers 200, but drops the monthly package, so the total
    /// reads as one-off grants only (observed on a real account: 36 packages instead of
    /// 37, and 2,389 credits instead of 2,889).
    static let packageWindowHorizon: TimeInterval = 3_185_136_000

    /// The request body the desktop client sends.
    static func requestBody(now: Date) -> [String: Any] {
        [
            "PageNumber": 1,
            "PageSize": 100,
            "ProductCode": productCode,
            "Status": [0, 3],
            "PackageEndTimeRangeBegin": Self.timestampFormatter.string(from: now),
            "PackageEndTimeRangeEnd": Self.timestampFormatter.string(
                from: now.addingTimeInterval(packageWindowHorizon)
            )
        ]
    }

    /// The wire format is `yyyy-MM-dd HH:mm:ss` in the machine's own zone, which is what
    /// the desktop app sends. Deliberately not ISO 8601.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private func decodeSnapshot(from data: Data, credential: WorkBuddyCredential) throws -> BalanceSnapshot {
        let payload: MeterResponse
        do {
            payload = try JSONDecoder().decode(MeterResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        guard payload.code == 0 else {
            // The envelope reports application-level failures with HTTP 200.
            throw payload.code == 401 ? BalanceProviderError.authenticationFailed
                : BalanceProviderError.serverError(statusCode: payload.code)
        }

        let packages = payload.data?.response?.data?.accounts ?? []
        return Self.makeSnapshot(
            from: packages,
            providerID: id,
            fetchedAt: now()
        )
    }

    /// Aggregate the packages into one balance.
    ///
    /// Exposed for tests: the arithmetic (which field to read, which packages count as
    /// granted, how expiry is ranked) is the part worth pinning down, and it needs no
    /// network.
    public static func makeSnapshot(
        from packages: [WorkBuddyPackage],
        providerID: ProviderID,
        fetchedAt: Date
    ) -> BalanceSnapshot {
        var total: Decimal = 0
        var granted: Decimal = 0
        var paid: Decimal = 0
        var monthlySize: Decimal = 0

        for package in packages {
            let remain = max(0, package.remaining)
            total += remain
            if package.isMonthly {
                paid += remain
                monthlySize += package.cycleSize
            } else {
                granted += remain
            }
        }

        return BalanceSnapshot(
            providerID: providerID,
            totalBalance: total,
            currency: creditCurrency,
            // Credits exist whenever any package has anything left. A zero total is a
            // real, displayable state (unlike an unreadable one), so it stays available
            // and the formatter's critical tone carries the warning.
            isAvailable: total > 0,
            grantedBalance: granted,
            toppedUpBalance: paid,
            // Two dates, two meanings. A one-off grant LAPSES at its nearest expiry; a
            // monthly allowance REFRESHES at its cycle end and never lapses. Summing them
            // into one date would answer neither question — the granted side is what can
            // be lost, so its nearest expiry is the one worth surfacing.
            expiringAt: Self.nextExpiry(in: packages, after: fetchedAt),
            refreshingAt: packages
                .filter(\.isMonthly)
                .compactMap(\.refreshAt)
                .min(),
            fetchedAt: fetchedAt
        )
    }

    /// The soonest date at which one-off credits are still at stake.
    ///
    /// Only a package that can still lose something counts, in two senses: it has to hold
    /// credits, and its expiry has to be ahead of this refresh. Skipping either reports a
    /// lapsed package as the next expiry — a date that has already passed. Real account,
    /// #102: a check-in package lapsed at 11/02 16:15 but kept a cycle end of 11/05, so the
    /// endpoint kept returning it, and `min()` showed 11/02 where the vendor's own screen
    /// said 11/08.
    static func nextExpiry(in packages: [WorkBuddyPackage], after fetchedAt: Date) -> Date? {
        packages
            .filter { !$0.isMonthly && $0.remaining > 0 }
            .compactMap(\.expiry)
            .filter { $0 > fetchedAt }
            .min()
    }
}

/// One package row from the billing response.
public struct WorkBuddyPackage: Equatable, Decodable {
    public let name: String
    public let capacityType: Int
    public let remaining: Decimal
    public let cycleSize: Decimal
    public let cycleEnd: Date?
    public let expiresAt: Date?

    /// Capacity type 4 is the monthly cycle; every other value is a one-off grant.
    public var isMonthly: Bool { capacityType == 4 }

    /// When this package's credits are lost. Monthly packages refresh instead.
    public var expiry: Date? { isMonthly ? nil : (expiresAt ?? cycleEnd) }

    /// When a monthly package's allowance is topped back up. One-off grants never
    /// refresh, so they answer nil.
    public var refreshAt: Date? { isMonthly ? cycleEnd : nil }

    private enum CodingKeys: String, CodingKey {
        case name = "PackageName"
        case capacityType = "CapacityType"
        case cycleCapacityRemain = "CycleCapacityRemain"
        case cycleCapacityRemainPrecise = "CycleCapacityRemainPrecise"
        case capacityRemain = "CapacityRemain"
        case capacityRemainPrecise = "CapacityRemainPrecise"
        case cycleCapacitySize = "CycleCapacitySize"
        case cycleCapacitySizePrecise = "CycleCapacitySizePrecise"
        case capacitySize = "CapacitySize"
        case cycleEnd = "CycleEndTime"
        case expiresAt = "ExpiredTime"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        capacityType = (try? container.decodeIfPresent(Int.self, forKey: .capacityType)) ?? 1

        // A calendar-cycle package reports through the `Cycle*` fields and a one-off
        // through the plain ones; which pair carries the number depends on the package,
        // so prefer the precise spelling and fall back across both families.
        remaining = Self.decimal(container, [
            .cycleCapacityRemainPrecise, .cycleCapacityRemain,
            .capacityRemainPrecise, .capacityRemain
        ]) ?? 0
        cycleSize = Self.decimal(container, [.cycleCapacitySizePrecise, .cycleCapacitySize]) ?? 0

        cycleEnd = Self.date(container, .cycleEnd)
        expiresAt = Self.date(container, .expiresAt)
    }

    /// Test-only initializer.
    public init(
        name: String,
        capacityType: Int,
        remaining: Decimal,
        cycleSize: Decimal = 0,
        cycleEnd: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.name = name
        self.capacityType = capacityType
        self.remaining = remaining
        self.cycleSize = cycleSize
        self.cycleEnd = cycleEnd
        self.expiresAt = expiresAt
    }

    /// Read the first present decimal, across every spelling the endpoint uses.
    ///
    /// The `Precise` fields are strings carrying ten fractional digits; the plain ones
    /// are integers. A package with neither contributes 0 rather than failing the whole
    /// response.
    private static func decimal(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ keys: [CodingKeys]
    ) -> Decimal? {
        for key in keys {
            if let text = try? container.decodeIfPresent(String.self, forKey: key),
               let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) {
                return value
            }
            if let number = try? container.decodeIfPresent(Decimal.self, forKey: key) {
                return number
            }
            if let number = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Decimal(number)
            }
        }
        return nil
    }

    /// The endpoint may send a date as either a formatted string or epoch millis.
    private static func date(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Date? {
        if let text = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = parseTimestamp(text) {
            return parsed
        }
        if let millis = try? container.decodeIfPresent(Double.self, forKey: key), millis > 0 {
            return Date(timeIntervalSince1970: millis / 1000)
        }
        return nil
    }

    /// Parse `yyyy-MM-dd HH:mm:ss`, the format the billing side uses.
    ///
    /// Empty strings are common (a one-off package often leaves `ExpiredTime` blank), so
    /// blank parses to nil rather than to a bogus date.
    public static func parseTimestamp(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return timestampParser.date(from: trimmed)
    }

    private static let timestampParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

// MARK: - Wire envelope

/// `{code, msg, data:{Response:{Data:{Accounts:[...]}}}}` — the billing envelope nests
/// four levels deep, and every level is optional in practice.
private struct MeterResponse: Decodable {
    let code: Int
    let data: MeterData?

    private enum CodingKeys: String, CodingKey {
        case code, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? container.decodeIfPresent(Int.self, forKey: .code)) ?? 0
        data = try? container.decodeIfPresent(MeterData.self, forKey: .data)
    }
}

private struct MeterData: Decodable {
    let response: MeterInner?

    private enum CodingKeys: String, CodingKey {
        case response = "Response"
    }
}

private struct MeterInner: Decodable {
    let data: MeterAccounts?

    private enum CodingKeys: String, CodingKey {
        case data = "Data"
    }
}

private struct MeterAccounts: Decodable {
    let accounts: [WorkBuddyPackage]?

    private enum CodingKeys: String, CodingKey {
        case accounts = "Accounts"
    }
}
