import APIInquiryCore

enum UsageConsoleSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case api = "API"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .home:
            return "house"
        case .api:
            return "key"
        case .settings:
            return "gearshape"
        }
    }

    func displayName(strings: LocalizedStrings) -> String {
        switch self {
        case .home:
            return strings.homeSection
        case .api:
            return strings.apiSection
        case .settings:
            return strings.settingsSection
        }
    }

    func title(strings: LocalizedStrings) -> String {
        switch self {
        case .home:
            return strings.providersTitle
        case .api:
            return strings.apiProvidersTitle
        case .settings:
            return strings.settingsSection
        }
    }
}
