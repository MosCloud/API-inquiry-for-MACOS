import Foundation

public enum ProviderToneResolver {
    public static func statusTone(for state: BalanceState) -> ProviderStatusTone {
        switch state {
        case .notConfigured:
            return .neutral
        case .loading:
            return .refreshing
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? .success : .warning
            case .planUsage(let usage):
                return usage.isAvailable ? .success : .warning
            case .quotaUsage(let usage):
                return usage.isAvailable ? .success : .warning
            }
        case .failed:
            return .warning
        }
    }

    public static func consoleSummaryStatusTone(for state: BalanceState) -> ProviderStatusTone {
        guard case .failed(_, let kind, _) = state else {
            return statusTone(for: state)
        }

        switch kind {
        case .usageLimitReached, .planExpired:
            return .warning
        case .authenticationFailed, .rateLimited, .networkUnavailable, .serverError, .decodingFailed, .invalidResponse, .unknown:
            return .neutral
        }
    }

    public static func summaryHealthTone(for state: BalanceState) -> ProviderAmountTone {
        guard case .loaded(let snapshot) = state else {
            return .neutral
        }

        switch snapshot {
        case .balance(let balance):
            return balanceAmountTone(for: balance.totalBalance)
        case .planUsage(let usage):
            return planUsageAmountTone(for: usage.usagePercentage)
        case .quotaUsage(let usage):
            return aggregateAmountTone(usage.windows.map { remainingQuotaAmountTone(for: $0.remainingPercentage) })
        }
    }

    public static func balanceAmountTone(for amount: Decimal) -> ProviderAmountTone {
        if amount >= Decimal(50) {
            return .good
        }
        if amount >= Decimal(10) {
            return .warning
        }
        return .critical
    }

    public static func planUsageAmountTone(for usagePercentage: Decimal) -> ProviderAmountTone {
        if usagePercentage <= Decimal(40) {
            return .good
        }
        if usagePercentage <= Decimal(80) {
            return .warning
        }
        return .critical
    }

    public static func remainingQuotaAmountTone(for remainingPercentage: Decimal) -> ProviderAmountTone {
        if remainingPercentage >= Decimal(60) {
            return .good
        }
        if remainingPercentage >= Decimal(20) {
            return .warning
        }
        return .critical
    }

    public static func aggregateAmountTone(_ tones: [ProviderAmountTone]) -> ProviderAmountTone {
        if tones.contains(.critical) {
            return .critical
        }
        if tones.contains(.warning) {
            return .warning
        }
        if tones.contains(.good) {
            return .good
        }
        return .neutral
    }
}
