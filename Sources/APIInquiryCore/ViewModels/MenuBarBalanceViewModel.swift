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

    private let coordinator: MultiProviderBalanceCoordinator
    private let lastRefreshTimeFormatter: LastRefreshTimeFormatter
    private let languageStore: AppLanguageStore?
    private var cancellables: Set<AnyCancellable> = []

    public convenience init() {
        let registry = BuiltInProviderRegistry.default
        let credentialStore = KeychainCredentialStore()
        let coordinator = MultiProviderBalanceCoordinator(
            registrations: registry.registrations,
            credentialStore: credentialStore,
            preferences: InMemoryProviderPreferencesStore(
                addedProviderIDs: [.deepseek],
                primaryProviderID: .deepseek
            ),
            defaultProviderID: registry.defaultProviderID
        )
        self.init(coordinator: coordinator)
    }

    public init(
        coordinator: MultiProviderBalanceCoordinator,
        displayMode: MenuBarDisplayMode = .text,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
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
        activeDescriptor?.displayName ?? strings.provider
    }

    public var state: BalanceState {
        activeState
    }

    public var menuBarTitle: String {
        guard let prefix = activeDescriptor?.menuTitlePrefix,
              !prefix.isEmpty else {
            return menuBarValueText
        }
        return "\(prefix) \(menuBarValueText)"
    }

    public var menuBarIconFallbackText: String {
        guard let prefix = activeDescriptor?.menuPrefix,
              !prefix.isEmpty else {
            return "API"
        }
        return prefix
    }

    public var menuBarValueText: String {
        ProviderDisplayFormatter.menuValueText(for: activeState, isCredentialConfigured: isCredentialConfigured, strings: strings)
    }

    public var panelBalanceText: String {
        ProviderDisplayFormatter.detailText(for: activeState.lastSnapshot, strings: strings)
    }

    public var primaryDisplayParts: PrimaryProviderDisplayParts {
        guard let descriptor = activeDescriptor else {
            return PrimaryProviderDisplayParts(
                providerID: .deepseek,
                displayName: strings.provider,
                detailKind: .balance,
                leadingText: "",
                amountText: "--",
                amountValue: nil,
                amountTone: .neutral,
                trailingText: "",
                captionText: ""
            )
        }

        return ProviderDisplayFormatter.primaryDisplayParts(descriptor: descriptor, state: activeState, strings: strings)
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
        return coordinator.addedProviderIDs
            .filter { $0 != coordinator.primaryProviderID }
            .compactMap { id in
                guard let descriptor = coordinator.descriptor(for: id) else {
                    return nil
                }
                let state = coordinator.state(for: id)
                return ProviderDetailRow(
                    providerID: id,
                    displayName: descriptor.secondaryDisplayName,
                    detailText: ProviderDisplayFormatter.secondaryDetailText(for: state.lastSnapshot, strings: strings),
                    quotaWindowRows: quotaWindowRows(for: state, suffixText: "%"),
                    statusText: ProviderDisplayFormatter.statusText(for: state, strings: strings),
                    statusTone: ProviderDisplayFormatter.statusTone(for: state),
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
                amountValue: ProviderValueFormatter.quotaWindowAmountValue(for: window),
                amountTone: ProviderDisplayFormatter.quotaWindowAmountTone(for: window),
                suffixText: suffixText,
                detailText: "\(amountText)\(suffixText)",
                resetText: quotaWindowResetText(for: window),
                isAvailable: window.isAvailable
            )
        }
    }

    private func quotaWindowResetText(for window: QuotaWindowSnapshot) -> String? {
        window.resolvedKind == .week
            ? timeFormatter.resetDateText(for: window.resetAt)
            : timeFormatter.resetText(for: window.resetAt)
    }

    private func quotaWindowDisplayLabel(for label: String) -> String {
        strings.quotaWindowLabel(label)
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

    @discardableResult
    public func refresh() async -> Bool {
        await coordinator.refreshAddedProviders()

        if case .loaded = activeState {
            return true
        }

        return false
    }

    public func startAutoRefresh() {
        coordinator.startAutoRefresh()
    }

    public func stopAutoRefresh() {
        coordinator.stopAutoRefresh()
    }

    private var activeProvider: BalanceProvider? {
        coordinator.provider(for: coordinator.primaryProviderID)
    }

    private var activeDescriptor: ProviderDescriptor? {
        coordinator.primaryDescriptor
    }

    private var activeState: BalanceState {
        coordinator.state(for: coordinator.primaryProviderID)
    }

    private var isCredentialConfigured: Bool {
        coordinator.isCredentialConfigured(for: coordinator.primaryProviderID)
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
