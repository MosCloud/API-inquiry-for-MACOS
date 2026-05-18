import Foundation

public final class ZhipuCodingPlanProvider: BalanceProvider {
    public let id: ProviderID = .zhipuCodingPlan
    public let displayName = "Zhipu GLM Coding Plan"
    public let menuPrefix = "GLM"
    public let credentialAccount = "zhipu-coding-plan-api-key"
    public let homepageURL = URL(string: "https://bigmodel.cn/claude-code")!

    private let quotaURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date

    public init(
        quotaURL: URL = URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.quotaURL = quotaURL
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        var request = URLRequest(url: quotaURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return .planUsage(try decodeUsage(from: response.data))
        case 401:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeUsage(from data: Data) throws -> PlanUsageSnapshot {
        let response: ZhipuQuotaResponse
        do {
            response = try JSONDecoder().decode(ZhipuQuotaResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        if response.success == false {
            throw providerError(forBusinessCode: response.code)
        }

        guard let tokenLimit = response.data?.limits.first(where: { $0.type == "TOKENS_LIMIT" }) else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return PlanUsageSnapshot(
            providerID: id,
            windowLabel: "5h",
            usagePercentage: Decimal(tokenLimit.percentage),
            resetAt: tokenLimit.nextResetTime.map { Date(timeIntervalSince1970: Double($0) / 1000) },
            isAvailable: tokenLimit.percentage < 100,
            fetchedAt: now()
        )
    }

    private func providerError(forBusinessCode code: Int) -> BalanceProviderError {
        switch code {
        case 1000...1004:
            return .authenticationFailed
        case 1308, 1310:
            return .usageLimitReached
        case 1309:
            return .planExpired
        case 1302, 1303, 1305:
            return .rateLimited
        default:
            return .serverError(statusCode: code)
        }
    }
}

private struct ZhipuQuotaResponse: Decodable {
    let code: Int
    let msg: String?
    let success: Bool?
    let data: ZhipuQuotaData?

    enum CodingKeys: String, CodingKey {
        case code
        case msg
        case success
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intCode = try? container.decode(Int.self, forKey: .code) {
            code = intCode
        } else {
            let stringCode = try container.decode(String.self, forKey: .code)
            guard let intCode = Int(stringCode) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .code,
                    in: container,
                    debugDescription: "Code must be an integer or integer string."
                )
            }
            code = intCode
        }
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        data = try container.decodeIfPresent(ZhipuQuotaData.self, forKey: .data)
    }
}

private struct ZhipuQuotaData: Decodable {
    let limits: [ZhipuQuotaLimit]
}

private struct ZhipuQuotaLimit: Decodable {
    let type: String
    let usage: Int?
    let currentValue: Int?
    let percentage: Int
    let nextResetTime: Int?
}
