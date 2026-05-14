import Combine
import Foundation

@MainActor
public final class MenuBarBalanceViewModel: ObservableObject {
    @Published public var apiKeyInput = ""
    @Published public var displayMode: MenuBarDisplayMode
    @Published public private(set) var settingsMessage: String?
    @Published private var isCredentialConfigured: Bool

    public let providerDisplayName: String
    public let consoleURL = URL(string: "https://platform.deepseek.com/usage")!

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private let controller: BalanceRefreshController
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
        displayMode: MenuBarDisplayMode = .text
    ) {
        self.provider = provider
        self.credentialStore = credentialStore
        self.controller = controller
        self.providerDisplayName = provider.displayName
        self.displayMode = displayMode
        self.isCredentialConfigured = Self.hasConfiguredCredential(
            in: credentialStore,
            account: provider.credentialAccount
        )

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

    public var panelBalanceText: String {
        guard let snapshot = state.lastSnapshot else {
            return "--"
        }

        return Self.formatAmount(snapshot.totalBalance, currency: snapshot.currency, fractionDigits: 2, includeCurrencyCode: true)
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
        if case .failed(let message, _) = state {
            return message
        }
        return nil
    }

    public var lastRefreshText: String {
        guard let fetchedAt = state.lastSnapshot?.fetchedAt else {
            return "Last updated: --"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Last updated: \(formatter.string(from: fetchedAt))"
    }

    public var credentialStatusText: String {
        isCredentialConfigured ? "Configured" : "Not configured"
    }

    public var isAPIKeyConfigured: Bool {
        isCredentialConfigured
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

    public func beginReplacingAPIKey() {
        apiKeyInput = ""
        settingsMessage = nil
    }

    public func saveAPIKey() async {
        let apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            settingsMessage = "API key is required."
            return
        }

        do {
            try credentialStore.saveCredential(apiKey, forAccount: provider.credentialAccount)
            apiKeyInput = ""
            settingsMessage = nil
            isCredentialConfigured = true
            await controller.refresh()
        } catch {
            settingsMessage = Self.settingsMessage(for: error)
        }
    }

    public func deleteAPIKey() async {
        do {
            try credentialStore.deleteCredential(forAccount: provider.credentialAccount)
            apiKeyInput = ""
            settingsMessage = nil
            isCredentialConfigured = false
            controller.markNotConfigured()
        } catch {
            settingsMessage = Self.settingsMessage(for: error)
        }
    }

    private static func hasConfiguredCredential(in store: CredentialStore, account: String) -> Bool {
        guard let credential = try? store.credential(forAccount: account) else {
            return false
        }
        return !credential.isEmpty
    }

    private static func settingsMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return "API key could not be saved."
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
