import Combine
import Foundation

public struct ProviderRuntime {
    public let descriptor: ProviderDescriptor
    public let provider: BalanceProvider
    public let controller: BalanceRefreshController
}

@MainActor
public final class MultiProviderBalanceCoordinator: ObservableObject {
    private let credentialStore: CredentialStore
    private let preferences: ProviderPreferencesStore
    private let providerOrder: [ProviderID]
    private let runtimesByProviderID: [ProviderID: ProviderRuntime]
    private let defaultProviderID: ProviderID
    private var cancellables: Set<AnyCancellable> = []
    private var isAutoRefreshStarted = false

    public init(
        registrations: [ProviderRegistration],
        credentialStore: CredentialStore,
        preferences: ProviderPreferencesStore,
        defaultProviderID: ProviderID = BuiltInProviderRegistry.default.defaultProviderID,
        initialStatesByProviderID: [ProviderID: BalanceState] = [:],
        controllersByProviderID: [ProviderID: BalanceRefreshController] = [:],
        localizedStrings: @escaping () -> LocalizedStrings = { LocalizedStrings(language: .en) }
    ) {
        self.credentialStore = credentialStore
        self.preferences = preferences
        self.providerOrder = registrations.map(\.descriptor.id)
        self.runtimesByProviderID = Dictionary(
            uniqueKeysWithValues: registrations.map { registration in
                let descriptor = registration.descriptor
                let provider = registration.makeProvider()
                precondition(
                    provider.id == descriptor.id,
                    "Provider registration mismatch: descriptor \(descriptor.id.rawValue), provider \(provider.id.rawValue)"
                )
                return (
                    descriptor.id,
                    ProviderRuntime(
                        descriptor: descriptor,
                        provider: provider,
                        controller: controllersByProviderID[descriptor.id] ?? BalanceRefreshController(
                            provider: provider,
                            credentialStore: credentialStore,
                            credentialAccount: descriptor.credentialAccount,
                            initialState: initialStatesByProviderID[descriptor.id] ?? .notConfigured,
                            localizedStrings: localizedStrings
                        )
                    )
                )
            }
        )
        self.defaultProviderID = defaultProviderID

        for runtime in runtimesByProviderID.values {
            runtime.controller.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }

        normalizePreferences()
    }

    public var addedProviderIDs: [ProviderID] {
        preferences.addedProviderIDs
    }

    public var availableProviderIDsToAdd: [ProviderID] {
        providerOrder.filter { !addedProviderIDs.contains($0) }
    }

    public var primaryProviderID: ProviderID {
        normalizedPrimaryProviderID()
    }

    public func provider(for id: ProviderID) -> BalanceProvider? {
        runtimesByProviderID[id]?.provider
    }

    public func descriptor(for id: ProviderID) -> ProviderDescriptor? {
        runtimesByProviderID[id]?.descriptor
    }

    public var primaryDescriptor: ProviderDescriptor? {
        descriptor(for: primaryProviderID)
    }

    public func state(for id: ProviderID) -> BalanceState {
        runtimesByProviderID[id]?.controller.state ?? .notConfigured
    }

    public func controller(for id: ProviderID) -> BalanceRefreshController? {
        runtimesByProviderID[id]?.controller
    }

    public func isCredentialConfigured(for id: ProviderID) -> Bool {
        guard let descriptor = descriptor(for: id),
              let credential = try? credentialStore.credential(forAccount: descriptor.credentialAccount) else {
            return false
        }
        return !credential.isEmpty
    }

    public func addProvider(_ id: ProviderID) {
        guard runtimesByProviderID[id] != nil,
              !preferences.addedProviderIDs.contains(id) else {
            return
        }

        preferences.addedProviderIDs.append(id)
        if preferences.primaryProviderID == nil {
            preferences.primaryProviderID = id
        }
        if isAutoRefreshStarted {
            runtimesByProviderID[id]?.controller.startAutoRefresh()
        }
        objectWillChange.send()
    }

    public func removeProvider(_ id: ProviderID, deletingCredential: Bool) throws {
        guard addedProviderIDs.contains(id),
              addedProviderIDs.count > 1 else {
            return
        }

        if deletingCredential, let descriptor = descriptor(for: id) {
            try credentialStore.deleteCredential(forAccount: descriptor.credentialAccount)
        }

        runtimesByProviderID[id]?.controller.stopAutoRefresh()
        runtimesByProviderID[id]?.controller.markNotConfigured()
        preferences.addedProviderIDs.removeAll { $0 == id }
        if preferences.primaryProviderID == id {
            preferences.primaryProviderID = fallbackPrimaryProviderID()
        }
        objectWillChange.send()
    }

    public func setPrimaryProvider(_ id: ProviderID) {
        guard addedProviderIDs.contains(id) else {
            return
        }
        preferences.primaryProviderID = id
        objectWillChange.send()
    }

    public func refresh(_ id: ProviderID) async {
        await runtimesByProviderID[id]?.controller.refresh()
    }

    public func refreshAddedProviders() async {
        let controllers = addedProviderIDs.compactMap { runtimesByProviderID[$0]?.controller }

        await withTaskGroup(of: Void.self) { group in
            for controller in controllers {
                group.addTask {
                    await controller.refresh()
                }
            }
        }
    }

    public func startAutoRefresh() {
        isAutoRefreshStarted = true
        for id in addedProviderIDs {
            runtimesByProviderID[id]?.controller.startAutoRefresh()
        }
    }

    public func stopAutoRefresh() {
        isAutoRefreshStarted = false
        for runtime in runtimesByProviderID.values {
            runtime.controller.stopAutoRefresh()
        }
    }

    private func normalizePreferences() {
        let knownAddedIDs = preferences.addedProviderIDs.filter { runtimesByProviderID[$0] != nil }
        if knownAddedIDs.isEmpty {
            preferences.addedProviderIDs = runtimesByProviderID[defaultProviderID] == nil
                ? Array(providerOrder.prefix(1))
                : [defaultProviderID]
        } else {
            preferences.addedProviderIDs = knownAddedIDs
        }

        preferences.primaryProviderID = normalizedPrimaryProviderID()
    }

    private func normalizedPrimaryProviderID() -> ProviderID {
        if let primary = preferences.primaryProviderID,
           preferences.addedProviderIDs.contains(primary),
           runtimesByProviderID[primary] != nil {
            return primary
        }

        return fallbackPrimaryProviderID()
    }

    private func fallbackPrimaryProviderID() -> ProviderID {
        if preferences.addedProviderIDs.contains(defaultProviderID),
           runtimesByProviderID[defaultProviderID] != nil {
            return defaultProviderID
        }

        return preferences.addedProviderIDs.first(where: { runtimesByProviderID[$0] != nil })
            ?? defaultProviderID
    }
}
