import Foundation

public protocol BalanceProvider {
    var id: ProviderID { get }

    func fetchSnapshot(apiKey: String) async throws -> ProviderSnapshot
}

public extension BalanceProvider {
    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        let snapshot = try await fetchSnapshot(apiKey: apiKey)
        guard case .balance(let balanceSnapshot) = snapshot else {
            throw BalanceProviderError.invalidResponseKind
        }
        return balanceSnapshot
    }
}

public enum BalanceProviderError: Error, Equatable, LocalizedError {
    case invalidURL
    case authenticationFailed
    case rateLimited
    case serverError(statusCode: Int)
    case missingBalanceInfo
    case invalidBalanceAmount(String)
    case invalidResponseKind
    case usageLimitReached
    case planExpired
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Balance API URL is invalid."
        case .authenticationFailed:
            return "API key may be invalid. Replace or delete it in the console."
        case .rateLimited:
            return "Balance API rate limit reached. Try again shortly."
        case .serverError(let statusCode):
            return "Balance API returned HTTP \(statusCode). Try again shortly."
        case .missingBalanceInfo:
            return "Balance API did not return balance information."
        case .invalidBalanceAmount:
            return "Balance API returned an invalid balance amount."
        case .invalidResponseKind:
            return "Provider returned an unsupported response kind."
        case .usageLimitReached:
            return "Plan usage limit reached. Wait for the next reset."
        case .planExpired:
            return "Plan has expired. Renew it in the provider console."
        case .decodingFailed:
            return "Balance API response could not be decoded."
        }
    }
}

public extension BalanceProviderError {
    func localizedDescription(strings: LocalizedStrings) -> String {
        switch self {
        case .invalidURL:
            return strings.invalidBalanceAPIURL
        case .authenticationFailed:
            return strings.apiKeyMayBeInvalid
        case .rateLimited:
            return strings.balanceAPIRateLimitReached
        case .serverError(let statusCode):
            return strings.balanceAPIReturnedHTTP(statusCode)
        case .missingBalanceInfo:
            return strings.balanceAPIMissingBalanceInfo
        case .invalidBalanceAmount:
            return strings.invalidBalanceAmount
        case .invalidResponseKind:
            return strings.unsupportedResponseKind
        case .usageLimitReached:
            return strings.planUsageLimitReached
        case .planExpired:
            return strings.planHasExpired
        case .decodingFailed:
            return strings.balanceAPIResponseCouldNotBeDecoded
        }
    }

    var failureKind: BalanceFailureKind {
        switch self {
        case .authenticationFailed:
            return .authenticationFailed
        case .rateLimited:
            return .rateLimited
        case .serverError:
            return .serverError
        case .decodingFailed:
            return .decodingFailed
        case .usageLimitReached:
            return .usageLimitReached
        case .planExpired:
            return .planExpired
        case .missingBalanceInfo, .invalidBalanceAmount, .invalidResponseKind:
            return .invalidResponse
        case .invalidURL:
            return .unknown
        }
    }
}
