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

    public func makeProvider() -> BalanceProvider {
        makeProviderClosure()
    }
}
