public struct ProviderCatalog: Equatable {
    public let descriptors: [ProviderDescriptor]
    public let defaultProviderID: ProviderID

    public init(descriptors: [ProviderDescriptor], defaultProviderID: ProviderID) {
        self.descriptors = descriptors
        self.defaultProviderID = defaultProviderID
    }

    public func descriptor(for id: ProviderID) -> ProviderDescriptor? {
        descriptors.first { $0.id == id }
    }
}

public extension ProviderCatalog {
    static let `default` = ProviderCatalog(
        descriptors: BuiltInProviderRegistry.default.registrations.map(\.descriptor),
        defaultProviderID: BuiltInProviderRegistry.default.defaultProviderID
    )
}
