public struct PrimaryProviderDisplayParts: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailKind: ProviderDetailKind
    public let leadingText: String
    public let amountText: String
    public let amountValue: Double?
    public let amountTone: ProviderAmountTone
    public let trailingText: String
    public let captionText: String
}

public struct ProviderDetailRow: Equatable {
    public let providerID: ProviderID
    public let displayName: String
    public let detailText: String
    public let quotaWindowRows: [QuotaWindowDisplayRow]
    public let statusText: String
    public let statusTone: ProviderStatusTone
    public let lastRefreshText: String
    public let resetText: String?
}

public struct QuotaWindowDisplayRow: Equatable {
    public let label: String
    public let amountText: String
    public let amountValue: Double?
    public let amountTone: ProviderAmountTone
    public let suffixText: String
    public let detailText: String
    public let resetText: String?
    public let isAvailable: Bool
}

public enum ProviderStatusTone: Equatable {
    case neutral
    case success
    case refreshing
    case warning
}

public enum ProviderAmountTone: Equatable {
    case neutral
    case good
    case warning
    case critical
}
