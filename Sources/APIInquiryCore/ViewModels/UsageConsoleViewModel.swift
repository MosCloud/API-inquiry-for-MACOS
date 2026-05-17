import Combine
import Foundation

@MainActor
public final class UsageConsoleViewModel: ObservableObject {
    @Published public var apiKeyInput = ""
    @Published public private(set) var isAPIKeyDeleteConfirmationPresented = false
    @Published public private(set) var settingsFeedback: SettingsFeedback?
    @Published public private(set) var usageFeedback: SettingsFeedback?
    @Published public private(set) var usageDataset: UsageDataset?
    @Published private var isCredentialConfigured: Bool

    public let providerDisplayName: String
    public let officialUsageURL = URL(string: "https://platform.deepseek.com/usage")!

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private let controller: BalanceRefreshController
    private let usageDataStore: UsageDataStore
    private let parser: DeepSeekUsageCSVParser
    private var cancellables: Set<AnyCancellable> = []

    public init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController,
        usageDataStore: UsageDataStore = JSONUsageDataStore(),
        parser: DeepSeekUsageCSVParser = DeepSeekUsageCSVParser()
    ) {
        self.provider = provider
        self.credentialStore = credentialStore
        self.controller = controller
        self.usageDataStore = usageDataStore
        self.parser = parser
        self.providerDisplayName = provider.displayName
        self.isCredentialConfigured = Self.hasConfiguredCredential(
            in: credentialStore,
            account: provider.credentialAccount
        )
        self.usageDataset = try? usageDataStore.loadDataset()

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

    public var usageTotals: UsageTotals? {
        usageDataset?.totals
    }

    public var modelSummaries: [UsageModelSummary] {
        usageDataset?.modelSummaries ?? []
    }

    public var detailRecords: [UsageRecord] {
        (usageDataset?.records ?? []).sorted {
            if $0.occurredAt == $1.occurredAt {
                return $0.model < $1.model
            }
            return $0.occurredAt > $1.occurredAt
        }
    }

    public func refresh() async {
        await controller.refresh()
    }

    public func loadUsageData() {
        do {
            usageDataset = try usageDataStore.loadDataset()
            usageFeedback = nil
        } catch {
            usageFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "Usage data could not be loaded.")
            )
        }
    }

    public func importUsageCSV(
        _ csvText: String,
        sourceFileName: String,
        importedAt: Date = Date()
    ) {
        do {
            let dataset = try parser.parse(csvText, sourceFileName: sourceFileName, importedAt: importedAt)
            try usageDataStore.saveDataset(dataset)
            usageDataset = dataset
            usageFeedback = SettingsFeedback(
                kind: .success,
                message: "Imported \(dataset.records.count) usage records."
            )
        } catch {
            usageFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "Usage CSV could not be imported.")
            )
        }
    }

    public func importUsageCSVFile(at url: URL, importedAt: Date = Date()) {
        do {
            let csvText = try String(contentsOf: url, encoding: .utf8)
            importUsageCSV(csvText, sourceFileName: url.lastPathComponent, importedAt: importedAt)
        } catch {
            usageFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "Usage CSV could not be read.")
            )
        }
    }

    public func clearUsageData() {
        do {
            try usageDataStore.clearDataset()
            usageDataset = nil
            usageFeedback = SettingsFeedback(kind: .success, message: "Usage data cleared.")
        } catch {
            usageFeedback = SettingsFeedback(
                kind: .error,
                message: Self.settingsMessage(for: error, fallback: "Usage data could not be cleared.")
            )
        }
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
