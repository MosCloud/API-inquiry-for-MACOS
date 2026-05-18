import Combine
import Foundation

public struct APIProviderSummary: Equatable {
    public let id: ProviderID
    public let displayName: String
    public let homepageURL: URL
    public let apiKeyStatusText: String
    public let validationStatusText: String
    public let statusTone: ProviderStatusTone
    public let balanceText: String
    public let lastRefreshText: String
    public let isPrimary: Bool

    public init(
        id: ProviderID = .deepseek,
        displayName: String,
        homepageURL: URL,
        apiKeyStatusText: String,
        validationStatusText: String,
        statusTone: ProviderStatusTone = .neutral,
        balanceText: String,
        lastRefreshText: String = "Last updated: --",
        isPrimary: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.homepageURL = homepageURL
        self.apiKeyStatusText = apiKeyStatusText
        self.validationStatusText = validationStatusText
        self.statusTone = statusTone
        self.balanceText = balanceText
        self.lastRefreshText = lastRefreshText
        self.isPrimary = isPrimary
    }
}

@MainActor
public final class UsageConsoleViewModel: ObservableObject {
    @Published public var apiKeyInput = ""
    @Published public private(set) var isAPIKeyDeleteConfirmationPresented = false
    @Published public private(set) var settingsFeedback: SettingsFeedback?
    @Published public private(set) var apiKeyInputsByProviderID: [ProviderID: String] = [:]
    @Published public private(set) var settingsFeedbacksByProviderID: [ProviderID: SettingsFeedback] = [:]
    @Published public private(set) var apiKeyDeleteConfirmationProviderID: ProviderID?

    private var singleIsCredentialConfigured: Bool

    private let singleProvider: BalanceProvider?
    private let singleController: BalanceRefreshController?
    private let coordinator: MultiProviderBalanceCoordinator?
    private let credentialStore: CredentialStore
    private let lastRefreshTimeFormatter: LastRefreshTimeFormatter
    private var cancellables: Set<AnyCancellable> = []

    public init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter()
    ) {
        self.singleProvider = provider
        self.singleController = controller
        self.coordinator = nil
        self.credentialStore = credentialStore
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.singleIsCredentialConfigured = Self.hasConfiguredCredential(
            in: credentialStore,
            account: provider.credentialAccount
        )

        controller.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public init(
        coordinator: MultiProviderBalanceCoordinator,
        credentialStore: CredentialStore,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter()
    ) {
        self.singleProvider = nil
        self.singleController = nil
        self.coordinator = coordinator
        self.credentialStore = credentialStore
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.singleIsCredentialConfigured = false

        coordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var providerDisplayName: String {
        singleProvider?.displayName ?? coordinator?.provider(for: coordinator?.primaryProviderID ?? .deepseek)?.displayName ?? "Provider"
    }

    public var state: BalanceState {
        singleController?.state ?? .notConfigured
    }

    public var credentialStatusText: String {
        isAPIKeyConfigured ? "Configured" : "Not configured"
    }

    public var isAPIKeyConfigured: Bool {
        if let coordinator {
            return coordinator.isCredentialConfigured(for: coordinator.primaryProviderID)
        }

        return singleIsCredentialConfigured
    }

    public var availableProviderIDsToAdd: [ProviderID] {
        coordinator?.availableProviderIDsToAdd ?? []
    }

    public func displayName(for id: ProviderID) -> String {
        coordinator?.provider(for: id)?.displayName
            ?? singleProvider?.displayName
            ?? id.rawValue
    }

    public var providerSummaries: [APIProviderSummary] {
        guard let coordinator else {
            guard let provider = singleProvider else {
                return []
            }
            return [
                APIProviderSummary(
                    id: provider.id,
                    displayName: providerDisplayName,
                    homepageURL: provider.homepageURL,
                    apiKeyStatusText: credentialStatusText,
                    validationStatusText: validationStatusText(for: state),
                    statusTone: ProviderDisplayFormatter.statusTone(for: state),
                    balanceText: ProviderDisplayFormatter.detailText(for: state.lastSnapshot),
                    lastRefreshText: lastRefreshTimeFormatter.lastRefreshText(for: state.lastSnapshot?.fetchedAt),
                    isPrimary: true
                )
            ]
        }

        return coordinator.addedProviderIDs.compactMap { id in
            guard let provider = coordinator.provider(for: id) else {
                return nil
            }
            let state = coordinator.state(for: id)
            return APIProviderSummary(
                id: id,
                displayName: provider.displayName,
                homepageURL: provider.homepageURL,
                apiKeyStatusText: coordinator.isCredentialConfigured(for: id) ? "Configured" : "Not configured",
                validationStatusText: validationStatusText(for: state),
                statusTone: ProviderDisplayFormatter.statusTone(for: state),
                balanceText: ProviderDisplayFormatter.detailText(for: state.lastSnapshot),
                lastRefreshText: lastRefreshTimeFormatter.lastRefreshText(for: state.lastSnapshot?.fetchedAt),
                isPrimary: id == coordinator.primaryProviderID
            )
        }
    }

    public func refresh() async {
        if let coordinator {
            await coordinator.refreshAddedProviders()
            return
        }

        await singleController?.refresh()
    }

    public func addProvider(_ id: ProviderID) {
        coordinator?.addProvider(id)
    }

    public func removeProvider(_ id: ProviderID, deletingCredential: Bool = true) {
        do {
            try coordinator?.removeProvider(id, deletingCredential: deletingCredential)
            apiKeyInputsByProviderID[id] = nil
            settingsFeedbacksByProviderID[id] = nil
        } catch {
            settingsFeedbacksByProviderID[id] = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "Provider could not be removed.")
            )
        }
    }

    public func setPrimaryProvider(_ id: ProviderID) {
        coordinator?.setPrimaryProvider(id)
    }

    public func apiKeyInput(for id: ProviderID) -> String {
        apiKeyInputsByProviderID[id] ?? ""
    }

    public func setAPIKeyInput(_ value: String, for id: ProviderID) {
        apiKeyInputsByProviderID[id] = value
    }

    public func settingsFeedback(for id: ProviderID) -> SettingsFeedback? {
        settingsFeedbacksByProviderID[id]
    }

    public func isAPIKeyConfigured(for id: ProviderID) -> Bool {
        if let coordinator {
            return coordinator.isCredentialConfigured(for: id)
        }

        return singleProvider?.id == id && singleIsCredentialConfigured
    }

    public func beginReplacingAPIKey() {
        isAPIKeyDeleteConfirmationPresented = false
        apiKeyInput = ""
        settingsFeedback = nil
    }

    public func requestAPIKeyDeletion() {
        guard singleIsCredentialConfigured else {
            return
        }

        isAPIKeyDeleteConfirmationPresented = true
    }

    public func requestAPIKeyDeletion(for id: ProviderID) {
        guard isAPIKeyConfigured(for: id) else {
            return
        }

        apiKeyDeleteConfirmationProviderID = id
    }

    public func cancelAPIKeyDeletion() {
        isAPIKeyDeleteConfirmationPresented = false
        apiKeyDeleteConfirmationProviderID = nil
    }

    public func confirmAPIKeyDeletion() async {
        if let id = apiKeyDeleteConfirmationProviderID {
            apiKeyDeleteConfirmationProviderID = nil
            await deleteAPIKey(for: id)
            return
        }

        guard isAPIKeyDeleteConfirmationPresented else {
            return
        }

        isAPIKeyDeleteConfirmationPresented = false
        await deleteAPIKey()
    }

    public func saveAPIKey() async {
        guard let provider = singleProvider,
              let controller = singleController else {
            return
        }

        let apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        await saveAPIKey(
            apiKey,
            for: provider,
            refresh: { await controller.refresh() },
            state: { controller.state },
            clearInput: { self.apiKeyInput = "" },
            setFeedback: { self.settingsFeedback = $0 },
            setConfigured: { self.singleIsCredentialConfigured = $0 }
        )
    }

    public func saveAPIKey(for id: ProviderID) async {
        guard let coordinator,
              let provider = coordinator.provider(for: id) else {
            return
        }

        let apiKey = apiKeyInput(for: id).trimmingCharacters(in: .whitespacesAndNewlines)
        await saveAPIKey(
            apiKey,
            for: provider,
            refresh: { await coordinator.refresh(id) },
            state: { coordinator.state(for: id) },
            clearInput: { self.apiKeyInputsByProviderID[id] = "" },
            setFeedback: { self.settingsFeedbacksByProviderID[id] = $0 },
            setConfigured: { _ in }
        )
    }

    public func deleteAPIKey() async {
        guard let provider = singleProvider,
              let controller = singleController else {
            return
        }

        do {
            try credentialStore.deleteCredential(forAccount: provider.credentialAccount)
            apiKeyInput = ""
            isAPIKeyDeleteConfirmationPresented = false
            settingsFeedback = SettingsFeedback(kind: .success, message: "API key deleted.")
            singleIsCredentialConfigured = false
            controller.markNotConfigured()
        } catch {
            isAPIKeyDeleteConfirmationPresented = false
            settingsFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "API key could not be deleted.")
            )
        }
    }

    public func deleteAPIKey(for id: ProviderID) async {
        guard let coordinator,
              let provider = coordinator.provider(for: id) else {
            return
        }

        do {
            try credentialStore.deleteCredential(forAccount: provider.credentialAccount)
            apiKeyInputsByProviderID[id] = ""
            settingsFeedbacksByProviderID[id] = SettingsFeedback(kind: .success, message: "API key deleted.")
            coordinator.controller(for: id)?.markNotConfigured()
        } catch {
            settingsFeedbacksByProviderID[id] = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "API key could not be deleted.")
            )
        }
    }

    private func saveAPIKey(
        _ apiKey: String,
        for provider: BalanceProvider,
        refresh: () async -> Void,
        state: () -> BalanceState,
        clearInput: () -> Void,
        setFeedback: (SettingsFeedback?) -> Void,
        setConfigured: (Bool) -> Void
    ) async {
        guard !apiKey.isEmpty else {
            setFeedback(SettingsFeedback(kind: .error, message: "API key is required."))
            return
        }

        do {
            try credentialStore.saveCredential(apiKey, forAccount: provider.credentialAccount)
            setConfigured(true)
            await refresh()

            switch state() {
            case .loaded:
                clearInput()
                setFeedback(SettingsFeedback(kind: .success, message: "Saved securely."))
                setConfigured(true)
            case .failed:
                setFeedback(SettingsFeedback(
                    kind: .warning,
                    message: "API key saved, but refresh failed. API key may be invalid. Replace or delete it in the console."
                ))
                setConfigured(true)
            case .notConfigured, .loading:
                setFeedback(nil)
            }
        } catch {
            setFeedback(SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "API key could not be saved.")
            ))
        }
    }

    private func validationStatusText(for state: BalanceState) -> String {
        switch state {
        case .notConfigured:
            return "Not configured"
        case .loading:
            return "Checking"
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? "Active" : "Insufficient balance"
            case .planUsage(let usage):
                return usage.isAvailable ? "Plan available" : "Limit reached"
            }
        case .failed(_, let kind, _):
            switch kind {
            case .authenticationFailed:
                return "Invalid"
            case .usageLimitReached:
                return "Limit reached"
            case .planExpired:
                return "Plan expired"
            default:
                return "Unavailable"
            }
        }
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
}
