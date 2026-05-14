import Foundation

public protocol BalanceProvider {
    var id: ProviderID { get }
    var displayName: String { get }
    var menuPrefix: String { get }
    var credentialAccount: String { get }

    func fetchBalance(apiKey: String) async throws -> BalanceSnapshot
}

public enum BalanceProviderError: Error, Equatable, LocalizedError {
    case invalidURL
    case authenticationFailed
    case rateLimited
    case serverError(statusCode: Int)
    case missingBalanceInfo
    case invalidBalanceAmount(String)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "DeepSeek balance URL is invalid."
        case .authenticationFailed:
            return "API key may be invalid. Replace or delete it in settings."
        case .rateLimited:
            return "DeepSeek rate limit reached. Try again shortly."
        case .serverError(let statusCode):
            return "DeepSeek returned HTTP \(statusCode). Try again shortly."
        case .missingBalanceInfo:
            return "DeepSeek did not return balance information."
        case .invalidBalanceAmount(let value):
            return "DeepSeek returned an invalid balance amount: \(value)."
        case .decodingFailed:
            return "DeepSeek balance response could not be decoded."
        }
    }
}
