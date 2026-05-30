import Combine
import Foundation

public struct APIProviderSummary: Equatable {
    public let id: ProviderID
    public let displayName: String
    public let homepageURL: URL
    public let apiKeyStatusText: String
    public let apiAccessStatusText: String
    public let apiAccessPurposeText: String
    public let validationStatusText: String
    public let summaryBadgeText: String
    public let supportsAPIKeyManagement: Bool
    public let codexConfigTargetURL: URL?
    public let statusTone: ProviderStatusTone
    public let healthTone: ProviderAmountTone
    public let balanceText: String
    public let lastRefreshText: String
    public let planNextResetText: String?
    public let planNameText: String?
    public let isPrimary: Bool

    public init(
        id: ProviderID = .deepseek,
        displayName: String,
        homepageURL: URL,
        apiKeyStatusText: String,
        apiAccessStatusText: String? = nil,
        apiAccessPurposeText: String = "",
        validationStatusText: String,
        summaryBadgeText: String? = nil,
        supportsAPIKeyManagement: Bool = true,
        codexConfigTargetURL: URL? = nil,
        statusTone: ProviderStatusTone = .neutral,
        healthTone: ProviderAmountTone = .neutral,
        balanceText: String,
        lastRefreshText: String = "--",
        planNextResetText: String? = nil,
        planNameText: String? = nil,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.homepageURL = homepageURL
        self.apiKeyStatusText = apiKeyStatusText
        self.apiAccessStatusText = apiAccessStatusText ?? apiKeyStatusText
        self.apiAccessPurposeText = apiAccessPurposeText
        self.validationStatusText = validationStatusText
        self.summaryBadgeText = summaryBadgeText ?? validationStatusText
        self.supportsAPIKeyManagement = supportsAPIKeyManagement
        self.codexConfigTargetURL = codexConfigTargetURL
        self.statusTone = statusTone
        self.healthTone = healthTone
        self.balanceText = balanceText
        self.lastRefreshText = lastRefreshText
        self.planNextResetText = planNextResetText
        self.planNameText = planNameText
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

    private let coordinator: MultiProviderBalanceCoordinator
    private let credentialStore: CredentialStore
    private let lastRefreshTimeFormatter: LastRefreshTimeFormatter
    private let languageStore: AppLanguageStore?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        coordinator: MultiProviderBalanceCoordinator,
        credentialStore: CredentialStore,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
        self.coordinator = coordinator
        self.credentialStore = credentialStore
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.languageStore = languageStore

        coordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        languageStore?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var providerDisplayName: String {
        coordinator.primaryDescriptor?.displayName ?? strings.provider
    }

    public var state: BalanceState {
        coordinator.state(for: coordinator.primaryProviderID)
    }

    public var credentialStatusText: String {
        isAPIKeyConfigured ? strings.configured : strings.notConfigured
    }

    public var isAPIKeyConfigured: Bool {
        coordinator.isCredentialConfigured(for: coordinator.primaryProviderID)
    }

    public var availableProviderIDsToAdd: [ProviderID] {
        coordinator.availableProviderIDsToAdd
    }

    public var languageSelection: AppLanguage {
        get {
            languageStore?.selection ?? .en
        }
        set {
            languageStore?.selection = newValue
        }
    }

    public func displayName(for id: ProviderID) -> String {
        coordinator.descriptor(for: id)?.displayName ?? id.rawValue
    }

    public var providerSummaries: [APIProviderSummary] {
        return coordinator.addedProviderIDs.compactMap { id in
            guard let descriptor = coordinator.descriptor(for: id) else {
                return nil
            }
            let state = coordinator.state(for: id)
            let validationStatusText = validationStatusText(for: state)
            let isCredentialConfigured = coordinator.isCredentialConfigured(for: id)
            return APIProviderSummary(
                id: id,
                displayName: descriptor.displayName,
                homepageURL: descriptor.homepageURL,
                apiKeyStatusText: isCredentialConfigured ? strings.configured : strings.notConfigured,
                apiAccessStatusText: apiAccessStatusText(
                    for: descriptor,
                    isCredentialConfigured: isCredentialConfigured
                ),
                apiAccessPurposeText: apiAccessPurposeText(for: descriptor),
                validationStatusText: validationStatusText,
                summaryBadgeText: ProviderDisplayFormatter.summaryBadgeText(
                    for: state,
                    fallbackText: validationStatusText,
                    strings: strings
                ),
                supportsAPIKeyManagement: descriptor.credentialManagement.supportsConsoleCredentialManagement,
                codexConfigTargetURL: codexConfigTargetURL(for: descriptor),
                statusTone: providerSummaryStatusTone(for: state),
                healthTone: ProviderDisplayFormatter.summaryHealthTone(for: state),
                balanceText: ProviderDisplayFormatter.consoleDetailText(for: state.lastSnapshot, strings: strings),
                lastRefreshText: timeFormatter.lastRefreshText(for: state.lastSnapshot?.fetchedAt),
                planNextResetText: timeFormatter.planNextResetText(for: state.lastPlanUsageSnapshot?.resetAt),
                planNameText: state.lastQuotaUsageSnapshot?.planName,
                isPrimary: id == coordinator.primaryProviderID
            )
        }
    }

    public func refresh() async {
        await coordinator.refreshAddedProviders()
    }

    public func addProvider(_ id: ProviderID) {
        coordinator.addProvider(id)
    }

    public func removeProvider(_ id: ProviderID, deletingCredential: Bool = true) {
        do {
            try coordinator.removeProvider(
                id,
                deletingCredential: deletingCredential && supportsConsoleCredentialManagement(for: id)
            )
            apiKeyInputsByProviderID[id] = nil
            settingsFeedbacksByProviderID[id] = nil
        } catch {
            settingsFeedbacksByProviderID[id] = SettingsFeedback(
                kind: .error,
                message: settingsMessage(for: error, fallback: strings.providerCouldNotBeRemoved)
            )
        }
    }

    public func setPrimaryProvider(_ id: ProviderID) {
        coordinator.setPrimaryProvider(id)
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
        coordinator.isCredentialConfigured(for: id)
    }

    public func beginReplacingAPIKey() {
        isAPIKeyDeleteConfirmationPresented = false
        apiKeyInput = ""
        settingsFeedback = nil
    }

    public func requestAPIKeyDeletion() {
        let id = coordinator.primaryProviderID
        guard isAPIKeyConfigured(for: id),
              supportsConsoleCredentialManagement(for: id) else {
            return
        }

        isAPIKeyDeleteConfirmationPresented = true
    }

    public func requestAPIKeyDeletion(for id: ProviderID) {
        guard isAPIKeyConfigured(for: id),
              supportsConsoleCredentialManagement(for: id) else {
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
        let id = coordinator.primaryProviderID
        guard let descriptor = coordinator.descriptor(for: id),
              descriptor.credentialManagement.supportsConsoleCredentialManagement else {
            return
        }

        let apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        await saveAPIKey(
            apiKey,
            for: descriptor,
            refresh: { await self.coordinator.refresh(id) },
            state: { self.coordinator.state(for: id) },
            clearInput: { self.apiKeyInput = "" },
            setFeedback: { self.settingsFeedback = $0 },
            setConfigured: { _ in }
        )
    }

    public func saveAPIKey(for id: ProviderID) async {
        guard let descriptor = coordinator.descriptor(for: id),
              descriptor.credentialManagement.supportsConsoleCredentialManagement else {
            return
        }

        let apiKey = apiKeyInput(for: id).trimmingCharacters(in: .whitespacesAndNewlines)
        await saveAPIKey(
            apiKey,
            for: descriptor,
            refresh: { await coordinator.refresh(id) },
            state: { coordinator.state(for: id) },
            clearInput: { self.apiKeyInputsByProviderID[id] = "" },
            setFeedback: { self.settingsFeedbacksByProviderID[id] = $0 },
            setConfigured: { _ in }
        )
    }

    public func deleteAPIKey() async {
        await deleteAPIKey(for: coordinator.primaryProviderID)
    }

    public func deleteAPIKey(for id: ProviderID) async {
        guard let descriptor = coordinator.descriptor(for: id),
              descriptor.credentialManagement.supportsConsoleCredentialManagement else {
            return
        }

        do {
            try credentialStore.deleteCredential(forAccount: descriptor.credentialAccount)
            apiKeyInputsByProviderID[id] = ""
            if id == coordinator.primaryProviderID {
                apiKeyInput = ""
                isAPIKeyDeleteConfirmationPresented = false
                settingsFeedback = SettingsFeedback(kind: .success, message: strings.apiKeyDeleted)
            }
            settingsFeedbacksByProviderID[id] = SettingsFeedback(kind: .success, message: strings.apiKeyDeleted)
            coordinator.controller(for: id)?.markNotConfigured()
        } catch {
            settingsFeedbacksByProviderID[id] = SettingsFeedback(
                kind: .error,
                message: settingsMessage(for: error, fallback: strings.apiKeyCouldNotBeDeleted)
            )
        }
    }

    private func saveAPIKey(
        _ apiKey: String,
        for descriptor: ProviderDescriptor,
        refresh: () async -> Void,
        state: () -> BalanceState,
        clearInput: () -> Void,
        setFeedback: (SettingsFeedback?) -> Void,
        setConfigured: (Bool) -> Void
    ) async {
        guard !apiKey.isEmpty else {
            setFeedback(SettingsFeedback(kind: .error, message: strings.apiKeyRequired))
            return
        }

        do {
            try credentialStore.saveCredential(apiKey, forAccount: descriptor.credentialAccount)
            setConfigured(true)
            await refresh()

            switch state() {
            case .loaded:
                clearInput()
                setFeedback(SettingsFeedback(kind: .success, message: strings.savedSecurely))
                setConfigured(true)
            case .failed:
                setFeedback(SettingsFeedback(
                    kind: .warning,
                    message: strings.apiKeySavedButRefreshFailed
                ))
                setConfigured(true)
            case .notConfigured, .loading:
                setFeedback(nil)
            }
        } catch {
            setFeedback(SettingsFeedback(
                kind: .error,
                message: settingsMessage(for: error, fallback: strings.apiKeyCouldNotBeSaved)
            ))
        }
    }

    private func validationStatusText(for state: BalanceState) -> String {
        switch state {
        case .notConfigured:
            return strings.notConfigured
        case .loading:
            return strings.checking
        case .loaded(let snapshot):
            switch snapshot {
            case .balance(let balance):
                return balance.isAvailable ? strings.active : strings.insufficientBalance
            case .planUsage(let usage):
                return usage.isAvailable ? strings.planAvailable : strings.limitReached
            case .quotaUsage(let usage):
                return usage.isAvailable ? strings.quotaAvailable : strings.quotaExhausted
            }
        case .failed(_, let kind, _):
            switch kind {
            case .authenticationFailed:
                return strings.invalid
            case .usageLimitReached:
                return strings.limitReached
            case .planExpired:
                return strings.planExpired
            default:
                return strings.unavailable
            }
        }
    }

    private func apiAccessStatusText(
        for descriptor: ProviderDescriptor,
        isCredentialConfigured: Bool
    ) -> String {
        if descriptor.credentialManagement.supportsConsoleCredentialManagement {
            return isCredentialConfigured ? strings.configured : strings.notConfigured
        }

        return isCredentialConfigured ? strings.loaded : strings.notLoaded
    }

    private func apiAccessPurposeText(for descriptor: ProviderDescriptor) -> String {
        switch descriptor.accessPurpose {
        case .prepaidBalance:
            return strings.prepaidBalanceCheckPurpose
        case .planQuota:
            return strings.planBalanceCheckPurpose
        }
    }

    private func codexConfigTargetURL(for descriptor: ProviderDescriptor) -> URL? {
        guard descriptor.credentialManagement == .localExternalConfiguration else {
            return nil
        }

        return (credentialStore as? CodexCredentialStore)?.codexConfigTargetURL()
    }

    private func providerSummaryStatusTone(for state: BalanceState) -> ProviderStatusTone {
        ProviderToneResolver.consoleSummaryStatusTone(for: state)
    }

    private static func settingsMessage(for error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return fallback
    }

    private func settingsMessage(for error: Error, fallback: String) -> String {
        if let providerError = error as? BalanceProviderError {
            return providerError.localizedDescription(strings: strings)
        }

        if let credentialError = error as? CredentialStoreError {
            return credentialError.localizedDescription(strings: strings)
        }

        if let httpError = error as? HTTPClientError {
            return httpError.localizedDescription(strings: strings)
        }

        return Self.settingsMessage(for: error, fallback: fallback)
    }

    private func supportsConsoleCredentialManagement(for id: ProviderID) -> Bool {
        coordinator.descriptor(for: id)?.credentialManagement.supportsConsoleCredentialManagement ?? true
    }

    public var localizedStrings: LocalizedStrings {
        strings
    }

    private var strings: LocalizedStrings {
        LocalizedStrings(language: languageStore?.resolvedLanguage ?? .en)
    }

    private var timeFormatter: LastRefreshTimeFormatter {
        lastRefreshTimeFormatter.withLanguage(strings.language)
    }
}
