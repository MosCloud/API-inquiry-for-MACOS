import Foundation

public enum ProviderID: String, Equatable {
    case deepseek
}

public enum MenuBarDisplayMode: Equatable {
    case text
    case iconAndText
}

public enum BalanceFailureKind: Equatable {
    case authenticationFailed
    case rateLimited
    case networkUnavailable
    case serverError
    case decodingFailed
    case invalidResponse
    case unknown
}

public enum BalanceRecoveryAction: Equatable {
    case retry
    case replaceKey
    case deleteKey
    case openConsole
}

public struct BalanceSnapshot: Equatable {
    public let providerID: ProviderID
    public let totalBalance: Decimal
    public let currency: String
    public let isAvailable: Bool
    public let grantedBalance: Decimal?
    public let toppedUpBalance: Decimal?
    public let fetchedAt: Date

    public init(
        providerID: ProviderID,
        totalBalance: Decimal,
        currency: String,
        isAvailable: Bool,
        grantedBalance: Decimal?,
        toppedUpBalance: Decimal?,
        fetchedAt: Date
    ) {
        self.providerID = providerID
        self.totalBalance = totalBalance
        self.currency = currency
        self.isAvailable = isAvailable
        self.grantedBalance = grantedBalance
        self.toppedUpBalance = toppedUpBalance
        self.fetchedAt = fetchedAt
    }
}

public enum BalanceState: Equatable {
    case notConfigured
    case loading(last: BalanceSnapshot?)
    case loaded(BalanceSnapshot)
    case failed(message: String, kind: BalanceFailureKind, last: BalanceSnapshot?)

    public var lastSnapshot: BalanceSnapshot? {
        switch self {
        case .notConfigured:
            return nil
        case .loading(let last):
            return last
        case .loaded(let snapshot):
            return snapshot
        case .failed(_, _, let last):
            return last
        }
    }
}
