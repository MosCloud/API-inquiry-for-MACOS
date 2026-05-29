import Foundation

public final class DeepSeekBalanceProvider: BalanceProvider {
    public let id: ProviderID = .deepseek

    private let baseURL: URL
    private let httpClient: HTTPClient
    private let now: () -> Date
    private let decimalLocale = Locale(identifier: "en_US_POSIX")

    public init(
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.now = now
    }

    public func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot {
        let url = baseURL.appending(path: "user/balance")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let response = try await httpClient.data(for: request)
        switch response.statusCode {
        case 200:
            return .balance(try decodeBalance(from: response.data))
        case 401:
            throw BalanceProviderError.authenticationFailed
        case 429:
            throw BalanceProviderError.rateLimited
        default:
            throw BalanceProviderError.serverError(statusCode: response.statusCode)
        }
    }

    private func decodeBalance(from data: Data) throws -> BalanceSnapshot {
        let deepSeekResponse: DeepSeekBalanceResponse
        do {
            deepSeekResponse = try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
        } catch {
            throw BalanceProviderError.decodingFailed
        }

        guard let selectedBalance = deepSeekResponse.balanceInfos.first(where: { $0.currency == "CNY" })
            ?? deepSeekResponse.balanceInfos.first else {
            throw BalanceProviderError.missingBalanceInfo
        }

        return BalanceSnapshot(
            providerID: id,
            totalBalance: try parseAmount(selectedBalance.totalBalance),
            currency: selectedBalance.currency,
            isAvailable: deepSeekResponse.isAvailable,
            grantedBalance: try parseOptionalAmount(selectedBalance.grantedBalance),
            toppedUpBalance: try parseOptionalAmount(selectedBalance.toppedUpBalance),
            fetchedAt: now()
        )
    }

    private func parseOptionalAmount(_ value: String?) throws -> Decimal? {
        guard let value else {
            return nil
        }
        return try parseAmount(value)
    }

    private func parseAmount(_ value: String) throws -> Decimal {
        guard isPlainDecimalString(value),
              let decimal = Decimal(string: value, locale: decimalLocale) else {
            throw BalanceProviderError.invalidBalanceAmount(value)
        }
        return decimal
    }

    private func isPlainDecimalString(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        var hasDigit = false
        var hasDecimalSeparator = false

        for (offset, scalar) in value.unicodeScalars.enumerated() {
            switch scalar.value {
            case 45:
                guard offset == 0 else {
                    return false
                }
            case 46:
                guard hasDigit, !hasDecimalSeparator else {
                    return false
                }
                hasDecimalSeparator = true
            case 48...57:
                hasDigit = true
            default:
                return false
            }
        }

        return hasDigit && value.unicodeScalars.last?.value != 46
    }
}

private struct DeepSeekBalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct DeepSeekBalanceInfo: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String?
    let toppedUpBalance: String?

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}
