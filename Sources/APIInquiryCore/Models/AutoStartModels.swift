public enum AutoStartStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    public var controlDisplay: AutoStartControlDisplay {
        switch self {
        case .enabled:
            return AutoStartControlDisplay(
                title: "AutoStart",
                systemImageName: "bolt.circle.fill",
                isHighlighted: true
            )

        case .disabled:
            return AutoStartControlDisplay(
                title: "AutoStart",
                systemImageName: "bolt.circle",
                isHighlighted: false
            )

        case .requiresApproval:
            return AutoStartControlDisplay(
                title: "AutoStart",
                systemImageName: "exclamationmark.circle",
                isHighlighted: false
            )

        case .unavailable:
            return AutoStartControlDisplay(
                title: "AutoStart",
                systemImageName: "slash.circle",
                isHighlighted: false
            )
        }
    }
}

public struct AutoStartControlDisplay: Equatable {
    public let title: String
    public let systemImageName: String
    public let isHighlighted: Bool

    public init(title: String, systemImageName: String, isHighlighted: Bool) {
        self.title = title
        self.systemImageName = systemImageName
        self.isHighlighted = isHighlighted
    }
}
