import Combine
import Foundation

public struct APIProviderSummary: Equatable {
    public let displayName: String
    public let homepageURL: URL
    public let apiKeyStatusText: String
    public let validationStatusText: String
    public let balanceText: String

    public init(
        displayName: String,
        homepageURL: URL,
        apiKeyStatusText: String,
        validationStatusText: String,
        balanceText: String
    ) {
        self.displayName = displayName
        self.homepageURL = homepageURL
        self.apiKeyStatusText = apiKeyStatusText
        self.validationStatusText = validationStatusText
        self.balanceText = balanceText
    }
}

@MainActor
public final class UsageConsoleViewModel: ObservableObject {
    @Published public var apiKeyInput = ""
    @Published public private(set) var isAPIKeyDeleteConfirmationPresented = false
    @Published public private(set) var settingsFeedback: SettingsFeedback?
    @Published private var isCredentialConfigured: Bool

    public let providerDisplayName: String

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private let controller: BalanceRefreshController
    private var cancellables: Set<AnyCancellable> = []

    public init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController
    ) {
        self.provider = provider
        self.credentialStore = credentialStore
        self.controller = controller
        self.providerDisplayName = provider.displayName
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

    public var credentialStatusText: String {
        isCredentialConfigured ? "Configured" : "Not configured"
    }

    public var isAPIKeyConfigured: Bool {
        isCredentialConfigured
    }

    public var providerSummaries: [APIProviderSummary] {
        [
            APIProviderSummary(
                displayName: providerDisplayName,
                homepageURL: provider.homepageURL,
                apiKeyStatusText: credentialStatusText,
                validationStatusText: validationStatusText,
                balanceText: balanceText
            )
        ]
    }

    public func refresh() async {
        await controller.refresh()
    }

    public func beginReplacingAPIKey() {
        isAPIKeyDeleteConfirmationPresented = false
        apiKeyInput = ""
        settingsFeedback = nil
    }

    public func requestAPIKeyDeletion() {
        guard isCredentialConfigured else {
            return
        }

        isAPIKeyDeleteConfirmationPresented = true
    }

    public func cancelAPIKeyDeletion() {
        isAPIKeyDeleteConfirmationPresented = false
    }

    public func confirmAPIKeyDeletion() async {
        guard isAPIKeyDeleteConfirmationPresented else {
            return
        }

        isAPIKeyDeleteConfirmationPresented = false
        await deleteAPIKey()
    }

    public func saveAPIKey() async {
        let apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            settingsFeedback = SettingsFeedback(kind: .error, message: "API key is required.")
            return
        }

        do {
            try credentialStore.saveCredential(apiKey, forAccount: provider.credentialAccount)
            isAPIKeyDeleteConfirmationPresented = false
            isCredentialConfigured = true
            await controller.refresh()

            switch state {
            case .loaded:
                apiKeyInput = ""
                settingsFeedback = SettingsFeedback(kind: .success, message: "Saved securely.")
                isCredentialConfigured = true
            case .failed:
                settingsFeedback = SettingsFeedback(
                    kind: .warning,
                    message: "API key saved, but balance refresh failed. API key may be invalid. Replace or delete it in the console."
                )
                isCredentialConfigured = true
            case .notConfigured, .loading:
                settingsFeedback = nil
            }
        } catch {
            settingsFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "API key could not be saved.")
            )
        }
    }

    public func deleteAPIKey() async {
        do {
            try credentialStore.deleteCredential(forAccount: provider.credentialAccount)
            apiKeyInput = ""
            isAPIKeyDeleteConfirmationPresented = false
            settingsFeedback = SettingsFeedback(kind: .success, message: "API key deleted.")
            isCredentialConfigured = false
            controller.markNotConfigured()
        } catch {
            isAPIKeyDeleteConfirmationPresented = false
            settingsFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "API key could not be deleted.")
            )
        }
    }

    private var validationStatusText: String {
        switch state {
        case .notConfigured:
            return "Not configured"
        case .loading:
            return "Checking"
        case .loaded(let snapshot):
            return snapshot.isAvailable ? "Active" : "Insufficient balance"
        case .failed(_, let kind, _):
            return kind == .authenticationFailed ? "Invalid" : "Unavailable"
        }
    }

    private var balanceText: String {
        guard let snapshot = state.lastBalanceSnapshot else {
            return "--"
        }

        return Self.formatAmount(snapshot.totalBalance, currency: snapshot.currency)
    }

    private static func hasConfiguredCredential(in store: CredentialStore, account: String) -> Bool {
        guard let credential = try? store.credential(forAccount: account) else {
            return false
        }
        return !credential.isEmpty
    }

    private static func settingsMessage(for error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return fallback
    }

    private static func formatAmount(_ amount: Decimal, currency: String) -> String {
        let currencyCode = currency.uppercased()
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountText = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"

        if currencyCode == "CNY" {
            return "¥\(amountText) \(currencyCode)"
        }

        return "\(amountText) \(currencyCode)"
    }
}
