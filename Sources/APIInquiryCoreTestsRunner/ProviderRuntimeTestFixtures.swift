import APIInquiryCore
import Foundation

func testDescriptor(for id: ProviderID) -> ProviderDescriptor {
    guard let descriptor = ProviderCatalog.default.descriptor(for: id) else {
        preconditionFailure("Missing test descriptor for \(id.rawValue)")
    }
    return descriptor
}

func testCredentialAccount(for id: ProviderID) -> String {
    testDescriptor(for: id).credentialAccount
}

func testRegistration(
    descriptor: ProviderDescriptor,
    provider: @escaping () -> BalanceProvider
) -> ProviderRegistration {
    ProviderRegistration(descriptor: descriptor, makeProvider: provider)
}

func testRegistration(
    for provider: BalanceProvider,
    descriptor: ProviderDescriptor? = nil
) -> ProviderRegistration {
    let runtimeDescriptor = descriptor ?? testDescriptor(for: provider.id)
    return testRegistration(descriptor: runtimeDescriptor, provider: { provider })
}

func testRegistrations(for providers: [BalanceProvider]) -> [ProviderRegistration] {
    providers.map { testRegistration(for: $0) }
}

@MainActor
func makeTestRefreshController(
    provider: BalanceProvider,
    credentialStore: CredentialStore,
    credentialAccount: String? = nil,
    initialState: BalanceState = .notConfigured,
    refreshInterval: TimeInterval = 300,
    localizedStrings: @escaping () -> LocalizedStrings = { LocalizedStrings(language: .en) }
) -> BalanceRefreshController {
    BalanceRefreshController(
        provider: provider,
        credentialStore: credentialStore,
        credentialAccount: credentialAccount ?? testCredentialAccount(for: provider.id),
        initialState: initialState,
        refreshInterval: refreshInterval,
        localizedStrings: localizedStrings
    )
}

@MainActor
func makeSingleProviderCoordinator(
    provider: BalanceProvider,
    credentialStore: CredentialStore,
    controller: BalanceRefreshController,
    descriptor: ProviderDescriptor? = nil
) -> MultiProviderBalanceCoordinator {
    MultiProviderBalanceCoordinator(
        registrations: [testRegistration(for: provider, descriptor: descriptor)],
        credentialStore: credentialStore,
        preferences: InMemoryProviderPreferencesStore(
            addedProviderIDs: [provider.id],
            primaryProviderID: provider.id
        ),
        defaultProviderID: provider.id,
        initialStatesByProviderID: [provider.id: controller.state],
        controllersByProviderID: [provider.id: controller]
    )
}

@MainActor
extension MenuBarBalanceViewModel {
    convenience init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController,
        displayMode: MenuBarDisplayMode = .text,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
        self.init(
            coordinator: makeSingleProviderCoordinator(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller
            ),
            displayMode: displayMode,
            lastRefreshTimeFormatter: lastRefreshTimeFormatter,
            languageStore: languageStore
        )
    }
}

@MainActor
extension UsageConsoleViewModel {
    convenience init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        controller: BalanceRefreshController,
        lastRefreshTimeFormatter: LastRefreshTimeFormatter = LastRefreshTimeFormatter(),
        languageStore: AppLanguageStore? = nil
    ) {
        self.init(
            coordinator: makeSingleProviderCoordinator(
                provider: provider,
                credentialStore: credentialStore,
                controller: controller
            ),
            credentialStore: credentialStore,
            lastRefreshTimeFormatter: lastRefreshTimeFormatter,
            languageStore: languageStore
        )
    }
}
