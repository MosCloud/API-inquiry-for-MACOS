import APIInquiryCore
import AppKit
import SwiftUI

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
}

private struct ProviderMetricItem {
    let title: String
    let value: String
}

private let providerHomepageButtonHeight: CGFloat = 40
private let projectHomepageURL = URL(string: "https://github.com/MosCloud/API-inquiry-for-MACOS")!

struct UsageConsoleView: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var replacingProviderIDs: Set<ProviderID> = []
    @State private var providerRemovalConfirmationID: ProviderID?

    init(viewModel: UsageConsoleViewModel, initialSection: UsageConsoleSection = .home) {
        self.viewModel = viewModel
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topNavigation

            Group {
                switch selectedSection {
                case .home:
                    homeSection
                case .api:
                    apiSection
                case .settings:
                    settingsSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .background(.regularMaterial)
    }

    private var topNavigation: some View {
        HStack(spacing: 6) {
            ForEach(UsageConsoleSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label {
                        Text(section.displayName(strings: strings))
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    } icon: {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(section == selectedSection ? Color.white : Color.secondary)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(section == selectedSection ? Color.accentColor : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(section == selectedSection ? Color.white.opacity(0.12) : Color.clear)
                }
                .help(section.displayName(strings: strings))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var homeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(strings.providersTitle)
                    .font(.headline)

                Spacer()

                Menu {
                    ForEach(viewModel.availableProviderIDsToAdd, id: \.self) { id in
                        Button(viewModel.displayName(for: id)) {
                            viewModel.addProvider(id)
                            selectedSection = .api
                        }
                    }
                } label: {
                    Label(strings.addProvider, systemImage: "plus")
                }
                .disabled(viewModel.availableProviderIDsToAdd.isEmpty)
            }

            ForEach(viewModel.providerSummaries, id: \.id) { summary in
                providerStatusRow(summary)
            }
        }
    }

    private func providerStatusRow(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            providerHeader(summary, showsMenuBarControl: true)
            providerMetrics(summary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            providerRowBackground(for: summary.healthTone)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(healthColor(for: summary.healthTone).opacity(summary.healthTone == .neutral ? 0 : 0.85))
                .frame(width: summary.healthTone == .neutral ? 0 : 3)
                .padding(.vertical, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(rowStrokeColor(for: summary.healthTone), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func providerRowBackground(for tone: ProviderAmountTone) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        switch tone {
        case .neutral:
            shape.fill(Color.secondary.opacity(0.10))
        case .good, .warning, .critical:
            shape
                .fill(Color.secondary.opacity(0.08))
                .overlay {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: healthColor(for: tone).opacity(0.22), location: 0),
                                Gradient.Stop(color: healthColor(for: tone).opacity(0.14), location: 0.34),
                                Gradient.Stop(color: healthColor(for: tone).opacity(0.06), location: 0.68),
                                Gradient.Stop(color: healthColor(for: tone).opacity(0.02), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
        }
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.apiProvidersTitle)
                .font(.headline)

            ForEach(viewModel.providerSummaries, id: \.id) { summary in
                apiProviderPanel(summary)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.settingsSection)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(strings.languageTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(strings.languageTitle, selection: languageSelectionBinding) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(strings.languageOptionTitle(language)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)

                Divider()

                HStack {
                    Text(strings.versionTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(appVersionText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    Button {
                        NSWorkspace.shared.open(projectHomepageURL)
                    } label: {
                        Label(strings.projectHomepage, systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(strings.projectHomepage)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func apiProviderPanel(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            providerAPIHeader(summary)

            if !viewModel.isAPIKeyConfigured(for: summary.id) || replacingProviderIDs.contains(summary.id) {
                SecureField(
                    viewModel.isAPIKeyConfigured(for: summary.id) ? strings.newAPIKeyPlaceholder : strings.apiKeyPlaceholder,
                    text: apiKeyBinding(for: summary.id)
                )
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button(viewModel.isAPIKeyConfigured(for: summary.id) ? strings.saveReplacement : strings.save) {
                        Task {
                            await viewModel.saveAPIKey(for: summary.id)
                            if viewModel.isAPIKeyConfigured(for: summary.id) {
                                replacingProviderIDs.remove(summary.id)
                            }
                        }
                    }
                    .disabled(viewModel.apiKeyInput(for: summary.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if replacingProviderIDs.contains(summary.id) {
                        Button(strings.cancel) {
                            replacingProviderIDs.remove(summary.id)
                            viewModel.setAPIKeyInput("", for: summary.id)
                        }
                    }

                    removeProviderButtonIfNeeded(summary)
                }
            } else {
                HStack(spacing: 8) {
                    Button(strings.replaceKey) {
                        replacingProviderIDs.insert(summary.id)
                        viewModel.setAPIKeyInput("", for: summary.id)
                    }

                    Button(strings.deleteKey, role: .destructive) {
                        viewModel.requestAPIKeyDeletion(for: summary.id)
                    }
                    removeProviderButtonIfNeeded(summary)
                }
            }

            if providerRemovalConfirmationID == summary.id {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.isAPIKeyConfigured(for: summary.id) ? strings.removeProviderAndDeleteAPIKeyConfirmation : strings.removeProviderConfirmation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button(strings.cancel) {
                            providerRemovalConfirmationID = nil
                        }
                        Button(strings.remove, role: .destructive) {
                            viewModel.removeProvider(summary.id)
                            replacingProviderIDs.remove(summary.id)
                            providerRemovalConfirmationID = nil
                        }
                    }
                }
                .padding(.top, 2)
            }

            if viewModel.apiKeyDeleteConfirmationProviderID == summary.id {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.deleteAPIKeyConfirmation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button(strings.cancel) {
                            viewModel.cancelAPIKeyDeletion()
                        }
                        Button(strings.delete, role: .destructive) {
                            Task {
                                await viewModel.confirmAPIKeyDeletion()
                                replacingProviderIDs.remove(summary.id)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            feedbackText(viewModel.settingsFeedback(for: summary.id))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func providerHeader(_ summary: APIProviderSummary, showsMenuBarControl: Bool) -> some View {
        HStack(spacing: 10) {
            providerHomepageButton(summary)

            if showsMenuBarControl {
                if summary.isPrimary {
                    menuBarBadge(strings.menuBar)
                } else {
                    Button(strings.showInMenuBar) {
                        viewModel.setPrimaryProvider(summary.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            statusBadge(summary.validationStatusText, healthTone: summary.healthTone, fallbackTone: summary.statusTone)
        }
        .frame(minHeight: 34)
    }

    private func providerAPIHeader(_ summary: APIProviderSummary) -> some View {
        HStack(spacing: 10) {
            providerHomepageButton(summary)

            Spacer()

            Text(summary.apiKeyStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(summary.apiKeyStatusText == strings.configured ? Color.green : Color.secondary)
        }
        .frame(minHeight: 32)
    }

    private func providerMetrics(_ summary: APIProviderSummary) -> some View {
        let metrics = providerMetricItems(for: summary)

        return HStack(spacing: 0) {
            ForEach(metrics.indices, id: \.self) { index in
                metricBox(title: metrics[index].title, value: metrics[index].value)

                if index < metrics.index(before: metrics.endIndex) {
                    metricSeparator
                }
            }
        }
    }

    private func providerMetricItems(for summary: APIProviderSummary) -> [ProviderMetricItem] {
        var metrics = [
            ProviderMetricItem(title: strings.apiKeyMetricTitle, value: summary.apiKeyStatusText),
            ProviderMetricItem(title: strings.statusMetricTitle, value: summary.validationStatusText),
            ProviderMetricItem(title: strings.detailMetricTitle, value: summary.balanceText)
        ]

        if let planNextResetText = summary.planNextResetText {
            metrics.append(
                ProviderMetricItem(
                    title: strings.planNextResetsMetricTitle,
                    value: strippedPrefix(planNextResetText, prefix: strings.planNextResetsPrefix)
                )
            )
        }

        if let planNameText = summary.planNameText {
            metrics.append(
                ProviderMetricItem(
                    title: strings.planMetricTitle,
                    value: planNameText
                )
            )
        }

        metrics.append(
            ProviderMetricItem(
                title: strings.updatedMetricTitle,
                value: strippedPrefix(summary.lastRefreshText, prefix: strings.lastUpdatedPrefix)
            )
        )

        return metrics
    }

    @ViewBuilder
    private func removeProviderButtonIfNeeded(_ summary: APIProviderSummary) -> some View {
        Button(strings.removeProvider, role: .destructive) {
            providerRemovalConfirmationID = summary.id
        }
        .disabled(viewModel.providerSummaries.count <= 1)
    }

    private func providerHomepageButton(_ summary: APIProviderSummary) -> some View {
        Button {
            NSWorkspace.shared.open(summary.homepageURL)
        } label: {
            HStack(spacing: 7) {
                providerLogo(summary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(height: providerHomepageButtonHeight)
            .foregroundStyle(Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(strings.openProviderAPIPage(summary.displayName))
    }

    @ViewBuilder
    private func providerLogo(_ summary: APIProviderSummary) -> some View {
        if let image = DeepSeekImages.headerLogoTemplate(for: summary.id) {
            let logoSize = DeepSeekImages.consoleLogoSize(for: summary.id)
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: logoSize.width, height: logoSize.height, alignment: .leading)
                .accessibilityLabel(summary.displayName)
        } else {
            Text(summary.displayName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func apiKeyBinding(for id: ProviderID) -> Binding<String> {
        Binding {
            viewModel.apiKeyInput(for: id)
        } set: { value in
            viewModel.setAPIKeyInput(value, for: id)
        }
    }

    private var languageSelectionBinding: Binding<AppLanguage> {
        Binding {
            viewModel.languageSelection
        } set: { value in
            viewModel.languageSelection = value
        }
    }

    private var strings: LocalizedStrings {
        viewModel.localizedStrings
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return "v\(version ?? "0.3.3")"
    }

    private func strippedPrefix(_ text: String, prefix: String) -> String {
        if text.hasPrefix("\(prefix): ") {
            return String(text.dropFirst(prefix.count + 2))
        }

        if text.hasPrefix("\(prefix)：") {
            return String(text.dropFirst(prefix.count + 1))
        }

        return text
    }

    private var metricSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 8)
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }

    private func statusBadge(
        _ text: String,
        healthTone: ProviderAmountTone,
        fallbackTone: ProviderStatusTone
    ) -> some View {
        let color = healthTone == .neutral ? statusColor(for: fallbackTone) : healthColor(for: healthTone)
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func menuBarBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(Color.white)
            .background(Color.accentColor.opacity(0.30))
            .overlay(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func feedbackText(_ feedback: SettingsFeedback?) -> some View {
        if let feedback {
            Text(feedback.message)
                .font(.caption)
                .foregroundStyle(feedbackColor(for: feedback.kind))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusColor(for tone: ProviderStatusTone) -> Color {
        switch tone {
        case .success:
            return .green
        case .refreshing:
            return .blue
        case .warning:
            return .orange
        case .neutral:
            return .secondary
        }
    }

    private func healthColor(for tone: ProviderAmountTone) -> Color {
        switch tone {
        case .neutral:
            return .secondary
        case .good:
            return .green
        case .warning:
            return Color(red: 1.0, green: 0.78, blue: 0.04)
        case .critical:
            return .red
        }
    }

    private func rowStrokeColor(for tone: ProviderAmountTone) -> Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.05)
        case .good, .warning, .critical:
            return healthColor(for: tone).opacity(0.22)
        }
    }

    private func feedbackColor(for kind: SettingsFeedbackKind) -> Color {
        switch kind {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
