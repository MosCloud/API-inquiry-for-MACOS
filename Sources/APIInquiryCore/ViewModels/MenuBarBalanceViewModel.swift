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

    private let singleProvider: BalanceProvider?
    private let singleCredentialStore: CredentialStore?
    private let singleController: BalanceRefreshController?
    private let coordinator: MultiProviderBalanceCoordinator?
    private let lastRefreshTimeFormatter: LastRefreshTimeFormatter
    private let languageStore: AppLanguageStore?
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
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
        self.singleProvider = provider
        self.singleCredentialStore = credentialStore
        self.singleController = controller
        self.coordinator = nil
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.languageStore = languageStore
        self.displayMode = displayMode

        controller.objectWillChange
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

    public init(
        coordinator: MultiProviderBalanceCoordinator,
        displayMode: MenuBarDisplayMode = .text,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
        self.singleProvider = nil
        self.singleCredentialStore = nil
        self.singleController = nil
        self.coordinator = coordinator
        self.lastRefreshTimeFormatter = lastRefreshTimeFormatter
        self.languageStore = languageStore
        self.displayMode = displayMode

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
        activeProvider?.displayName ?? strings.provider
    }

    public var state: BalanceState {
        activeState
    }

    public var menuBarTitle: String {
        if activeProvider?.id == .codex {
            return menuBarValueText
        }
        return "\(activeProvider?.menuPrefix ?? "") \(menuBarValueText)".trimmingCharacters(in: .whitespaces)
    }

    public var menuBarValueText: String {
        ProviderDisplayFormatter.menuValueText(for: activeState, isCredentialConfigured: isCredentialConfigured, strings: strings)
    }

    public var panelBalanceText: String {
        ProviderDisplayFormatter.detailText(for: activeState.lastSnapshot, strings: strings)
    }

    public var primaryDisplayParts: PrimaryProviderDisplayParts {
        guard let provider = activeProvider else {
            return PrimaryProviderDisplayParts(
                providerID: .deepseek,
                displayName: strings.provider,
                detailKind: .balance,
                leadingText: "",
                amountText: "--",
                amountTone: .neutral,
                trailingText: "",
                captionText: ""
            )
        }

        return ProviderDisplayFormatter.primaryDisplayParts(provider: provider, state: activeState, strings: strings)
    }

    public var panelBalanceDisplayParts: BalanceDisplayParts {
        let parts = primaryDisplayParts
        return BalanceDisplayParts(
            leadingText: parts.leadingText,
            amountText: parts.amountText,
            trailingText: parts.trailingText
        )
    }

    public var secondaryProviderRows: [ProviderDetailRow] {
        guard let coordinator else {
            return []
        }

        return coordinator.addedProviderIDs
            .filter { $0 != coordinator.primaryProviderID }
            .compactMap { id in
                guard let provider = coordinator.provider(for: id) else {
                    return nil
                }
                let state = coordinator.state(for: id)
                return ProviderDetailRow(
                    providerID: id,
                    displayName: providerDisplayName(for: provider),
                    detailText: ProviderDisplayFormatter.secondaryDetailText(for: state.lastSnapshot, strings: strings),
                    quotaWindowRows: quotaWindowRows(for: state, suffixText: "%"),
                    statusText: ProviderDisplayFormatter.statusText(for: state, strings: strings),
                    statusTone: ProviderDisplayFormatter.statusTone(for: state),
                    lastRefreshText: timeFormatter.lastRefreshText(for: state.lastSnapshot?.fetchedAt),
                    resetText: timeFormatter.resetText(for: state.lastPlanUsageSnapshot?.resetAt)
                )
            }
    }

    public var primaryQuotaWindowRows: [QuotaWindowDisplayRow] {
        guard let quota = activeState.lastQuotaUsageSnapshot else {
            return []
        }

        return quotaWindowRows(for: quota, suffixText: "% \(strings.compactRemainingSuffix)")
    }

    private func quotaWindowRows(for state: BalanceState, suffixText: String) -> [QuotaWindowDisplayRow] {
        guard let quota = state.lastQuotaUsageSnapshot else {
            return []
        }
        return quotaWindowRows(for: quota, suffixText: suffixText)
    }

    private func quotaWindowRows(for quota: QuotaUsageSnapshot, suffixText: String) -> [QuotaWindowDisplayRow] {
        quota.windows.map { window in
            let amountText = ProviderDisplayFormatter.quotaWindowAmountText(for: window)
            return QuotaWindowDisplayRow(
                label: quotaWindowDisplayLabel(for: window.label),
                amountText: amountText,
                amountTone: ProviderDisplayFormatter.quotaWindowAmountTone(for: window),
                suffixText: suffixText,
                detailText: "\(amountText)\(suffixText)",
                resetText: quotaWindowResetText(for: window),
                isAvailable: window.isAvailable
            )
        }
    }

    private func quotaWindowResetText(for window: QuotaWindowSnapshot) -> String? {
        window.label == "Week"
            ? timeFormatter.resetDateText(for: window.resetAt)
            : timeFormatter.resetText(for: window.resetAt)
    }

    private func quotaWindowDisplayLabel(for label: String) -> String {
        strings.quotaWindowLabel(label)
    }

    private func providerDisplayName(for provider: BalanceProvider) -> String {
        provider.id == .codex ? "OpenAI" : provider.displayName
    }

    public var statusText: String {
        ProviderDisplayFormatter.statusText(for: activeState, strings: strings)
    }

    public var statusTone: ProviderStatusTone {
        ProviderDisplayFormatter.statusTone(for: activeState)
    }

    public var errorText: String? {
        if case .failed(let message, _, _) = activeState {
            return message
        }
        return nil
    }

    public var lastRefreshText: String {
        timeFormatter.lastRefreshText(for: activeState.lastSnapshot?.fetchedAt)
    }

    public var resetText: String? {
        timeFormatter.resetText(for: activeState.lastPlanUsageSnapshot?.resetAt)
    }

    public var credentialStatusText: String {
        isCredentialConfigured ? strings.configured : strings.notConfigured
    }

    public var isAPIKeyConfigured: Bool {
        isCredentialConfigured
    }

    public var shouldShowSetupGuidance: Bool {
        !isCredentialConfigured
    }

    public var setupGuidanceText: String {
        strings.setupGuidance(providerDisplayName: providerDisplayName)
    }

    public var isRefreshDisabled: Bool {
        if case .loading = activeState {
            return true
        }
        return false
    }

    public var recoveryActions: [BalanceRecoveryAction] {
        guard case .failed(_, let kind, _) = activeState else {
            return []
        }

        switch kind {
        case .authenticationFailed, .usageLimitReached, .planExpired:
            return [.openConsole]
        case .rateLimited, .networkUnavailable, .serverError, .decodingFailed, .invalidResponse, .unknown:
            return [.retry]
        }
    }

    public func refresh() async {
        if let coordinator {
            await coordinator.refreshAddedProviders()
            return
        }

        await singleController?.refresh()
    }

    public func startAutoRefresh() {
        if let coordinator {
            coordinator.startAutoRefresh()
            return
        }

        singleController?.startAutoRefresh()
    }

    public func stopAutoRefresh() {
        if let coordinator {
            coordinator.stopAutoRefresh()
            return
        }

        singleController?.stopAutoRefresh()
    }

    private var activeProvider: BalanceProvider? {
        if let coordinator {
            return coordinator.provider(for: coordinator.primaryProviderID)
        }

        return singleProvider
    }

    private var activeState: BalanceState {
        if let coordinator {
            return coordinator.state(for: coordinator.primaryProviderID)
        }

        return singleController?.state ?? .notConfigured
    }

    private var isCredentialConfigured: Bool {
        if let coordinator {
            return coordinator.isCredentialConfigured(for: coordinator.primaryProviderID)
        }

        guard let store = singleCredentialStore,
              let account = singleProvider?.credentialAccount,
              let credential = try? store.credential(forAccount: account) else {
            return false
        }
        return !credential.isEmpty
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
