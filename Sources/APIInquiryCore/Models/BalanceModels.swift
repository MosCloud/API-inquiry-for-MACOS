import Foundation

public enum ProviderID: String, Equatable, Hashable, CaseIterable {
    case deepseek
    case zhipuCodingPlan
}

public enum ProviderDetailKind: Equatable {
    case balance
    case planUsage
}

public struct PlanUsageSnapshot: Equatable {
    public let providerID: ProviderID
    public let windowLabel: String
    public let usagePercentage: Decimal
    public let resetAt: Date?
    public let isAvailable: Bool
    public let fetchedAt: Date

    public init(
        providerID: ProviderID,
        windowLabel: String,
        usagePercentage: Decimal,
        resetAt: Date?,
        isAvailable: Bool,
        fetchedAt: Date
    ) {
        self.providerID = providerID
        self.windowLabel = windowLabel
        self.usagePercentage = usagePercentage
        self.resetAt = resetAt
        self.isAvailable = isAvailable
        self.fetchedAt = fetchedAt
    }
}

public enum ProviderSnapshot: Equatable {
    case balance(BalanceSnapshot)
    case planUsage(PlanUsageSnapshot)

    public var providerID: ProviderID {
        switch self {
        case .balance(let snapshot):
            return snapshot.providerID
        case .planUsage(let snapshot):
            return snapshot.providerID
        }
    }

    public var fetchedAt: Date {
        switch self {
        case .balance(let snapshot):
            return snapshot.fetchedAt
        case .planUsage(let snapshot):
            return snapshot.fetchedAt
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .balance(let snapshot):
            return snapshot.isAvailable
        case .planUsage(let snapshot):
            return snapshot.isAvailable
        }
    }
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
    case usageLimitReached
    case planExpired
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
    case loading(last: ProviderSnapshot?)
    case loaded(ProviderSnapshot)
    case failed(message: String, kind: BalanceFailureKind, last: ProviderSnapshot?)

    public var lastSnapshot: ProviderSnapshot? {
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

    public var lastBalanceSnapshot: BalanceSnapshot? {
        guard case .balance(let snapshot) = lastSnapshot else {
            return nil
        }
        return snapshot
    }

    public var lastPlanUsageSnapshot: PlanUsageSnapshot? {
        guard case .planUsage(let snapshot) = lastSnapshot else {
            return nil
        }
        return snapshot
    }
}
