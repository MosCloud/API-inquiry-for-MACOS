import Combine
import Foundation

public struct BalanceDisplayParts: Equatable {
    public let leadingText: String
    public let amountText: String
    public let trailingText: String
}

public enum SettingsFeedbackKind: Equatable {
    case success
    case warning
    case error
}

public struct SettingsFeedback: Equatable {
    public let kind: SettingsFeedbackKind
    public let message: String

    public init(kind: SettingsFeedbackKind, message: String) {
        self.kind = kind
        self.message = message
    }
}

@MainActor
public final class MenuBarBalanceViewModel: ObservableObject {
    @Published public var displayMode: MenuBarDisplayMode

    public let providerDisplayName: String

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private let controller: BalanceRefreshController
    private let lastRefreshTimeFormatter: LastRefreshTimeFormatter
    private var cancellables: Set<AnyCancellable> = []

    public convenience init() {
        let provider = DeepSeekBalanceProvider()
        let credentialStore = KeychainCredentialStore()
        let controller = BalanceRefreshController(provider: provider, credentialStore: credentialStore)
        self.init(provider: provider, credentialStore: credentialStore, controller: controller)
    }

    public init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController,
        displayMode: MenuBarDisplayMode = .text,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter()
    ) {
        self.provider = provider
        self.credentialStore = credentialStore
        self.controller = controller
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.providerDisplayName = provider.displayName
        self.displayMode = displayMode

        controller.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var state: BalanceState {
        controller.state
    }

    public var menuBarTitle: String {
        if case .notConfigured = state {
            return isCredentialConfigured ? "\(provider.menuPrefix) --" : "\(provider.menuPrefix) Setup"
        }

        guard let snapshot = state.lastSnapshot else {
            return "\(provider.menuPrefix) --"
        }

        return "\(provider.menuPrefix) \(Self.formatAmount(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 1, includeCurrencyCode: false))"
    }

    public var menuBarValueText: String {
        if case .notConfigured = state {
            return isCredentialConfigured ? "--" : "Setup"
        }

        guard let snapshot = state.lastSnapshot else {
            return "--"
        }

        return Self.formatAmount(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 1, includeCurrencyCode: false)
    }

    public var panelBalanceText: String {
        guard let snapshot = state.lastSnapshot else {
            return "--"
        }

        return Self.formatAmount(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 2, includeCurrencyCode: true)
    }

    public var panelBalanceDisplayParts: BalanceDisplayParts {
        guard let snapshot = state.lastSnapshot else {
            return BalanceDisplayParts(leadingText: "", amountText: "--", trailingText: "")
        }

        let currencyCode = snapshot.currency.uppercased()
        let amountText = Self.formatNumber(Self.truncate(snapshot.totalBalance, scale: 2), fractionDigits: 2)

        if currencyCode == "CNY" {
            return BalanceDisplayParts(leadingText: "¥", amountText: amountText, trailingText: currencyCode)
        }

        return BalanceDisplayParts(leadingText: "", amountText: amountText, trailingText: currencyCode)
    }

    public var statusText: String {
        switch state {
        case .notConfigured:
            return "Not configured"
        case .loading:
            return "Refreshing"
        case .loaded(let snapshot):
            return snapshot.isAvailable ? "Available" : "Balance insufficient"
        case .failed:
            return "Refresh failed"
        }
    }

    public var errorText: String? {
        if case .failed(let message, _, _) = state {
            return message
        }
        return nil
    }

    public var lastRefreshText: String {
        lastRefreshTimeFormatter.lastRefreshText(for: state.lastSnapshot?.fetchedAt)
    }

    public var credentialStatusText: String {
        isCredentialConfigured ? "Configured" : "Not configured"
    }

    public var isAPIKeyConfigured: Bool {
        isCredentialConfigured
    }

    public var shouldShowSetupGuidance: Bool {
        !isCredentialConfigured
    }

    public var setupGuidanceText: String {
        "Add a DeepSeek API key to start checking your balance."
    }

    public var isRefreshDisabled: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    public var recoveryActions: [BalanceRecoveryAction] {
        guard case .failed(_, let kind, _) = state else {
            return []
        }

        switch kind {
        case .authenticationFailed:
            return [.openConsole]
        case .rateLimited, .networkUnavailable, .serverError, .decodingFailed, .invalidResponse, .unknown:
            return [.retry]
        }
    }

    private var isCredentialConfigured: Bool {
        Self.hasConfiguredCredential(in: credentialStore, account: provider.credentialAccount)
    }

    public func refresh() async {
        await controller.refresh()
    }

    public func startAutoRefresh() {
        controller.startAutoRefresh()
    }

    public func stopAutoRefresh() {
        controller.stopAutoRefresh()
    }

    private static func hasConfiguredCredential(in store: CredentialStore, account: String) -> Bool {
        guard let credential = try? store.credential(forAccount: account) else {
            return false
        }
        return !credential.isEmpty
    }

    private static func formatAmount(
        _ amount: Decimal,
        currency: String,
        fractionDigits: Int,
        includeCurrencyCode: Bool
    ) -> String {
        let currencyCode = currency.uppercased()
        let number = formatNumber(truncate(amount, scale: fractionDigits), fractionDigits: fractionDigits)

        if currencyCode == "CNY" {
            return includeCurrencyCode ? "¥\(number) \(currencyCode)" : "¥\(number)"
        }

        return includeCurrencyCode ? "\(number) \(currencyCode)" : "\(currencyCode) \(number)"
    }

    private static func formatNumber(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"
    }

    private static func truncate(_ amount: Decimal, scale: Int) -> Decimal {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .down)
        return output
    }
}
