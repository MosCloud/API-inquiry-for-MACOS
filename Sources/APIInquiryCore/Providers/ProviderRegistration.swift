public struct ProviderRegistration {
    public let descriptor: ProviderDescriptor
    private let makeProviderClosure: () -> BalanceProvider

    public init(
        descriptor: ProviderDescriptor,
        makeProvider: @escaping () -> BalanceProvider
    ) {
        self.descriptor = descriptor
        self.makeProviderClosure = makeProvider
    }

    /// Provider factories should be lightweight and avoid credential, network, or persistent storage side effects.
    public func makeProvider() -> BalanceProvider {
        makeProviderClosure()
    }
}
