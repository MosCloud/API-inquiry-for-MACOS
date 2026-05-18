import APIInquiryCore
import AppKit
import SwiftUI

enum UsageConsoleSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case api = "API"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .home:
            return "house"
        case .api:
            return "key"
        }
    }
}

private struct ProviderMetricItem {
    let title: String
    let value: String
}

private let providerHomepageButtonHeight: CGFloat = 40

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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var topNavigation: some View {
        HStack(spacing: 6) {
            ForEach(UsageConsoleSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label {
                        Text(section.rawValue)
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
                .help(section.rawValue)
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
                Text("Providers")
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
                    Label("Add Provider", systemImage: "plus")
                }
                .disabled(viewModel.availableProviderIDsToAdd.isEmpty)
            }

            ForEach(viewModel.providerSummaries, id: \.id) { summary in
                providerStatusRow(summary)
            }
        }
    }

    private func providerStatusRow(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            providerHeader(summary, showsMenuBarControl: true)
            providerMetrics(summary)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API Providers")
                .font(.headline)

            ForEach(viewModel.providerSummaries, id: \.id) { summary in
                apiProviderPanel(summary)
            }
        }
    }

    private func apiProviderPanel(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            providerAPIHeader(summary)

            if !viewModel.isAPIKeyConfigured(for: summary.id) || replacingProviderIDs.contains(summary.id) {
                SecureField(viewModel.isAPIKeyConfigured(for: summary.id) ? "New API key" : "API key", text: apiKeyBinding(for: summary.id))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button(viewModel.isAPIKeyConfigured(for: summary.id) ? "Save Replacement" : "Save") {
                        Task {
                            await viewModel.saveAPIKey(for: summary.id)
                            if viewModel.isAPIKeyConfigured(for: summary.id) {
                                replacingProviderIDs.remove(summary.id)
                            }
                        }
                    }
                    .disabled(viewModel.apiKeyInput(for: summary.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if replacingProviderIDs.contains(summary.id) {
                        Button("Cancel") {
                            replacingProviderIDs.remove(summary.id)
                            viewModel.setAPIKeyInput("", for: summary.id)
                        }
                    }

                    removeProviderButtonIfNeeded(summary)
                }
            } else {
                HStack(spacing: 8) {
                    Button("Replace Key") {
                        replacingProviderIDs.insert(summary.id)
                        viewModel.setAPIKeyInput("", for: summary.id)
                    }

                    Button("Delete Key", role: .destructive) {
                        viewModel.requestAPIKeyDeletion(for: summary.id)
                    }
                    removeProviderButtonIfNeeded(summary)
                }
            }

            if providerRemovalConfirmationID == summary.id {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.isAPIKeyConfigured(for: summary.id) ? "Remove this provider and delete its saved API key?" : "Remove this provider?")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            providerRemovalConfirmationID = nil
                        }
                        Button("Remove", role: .destructive) {
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
                    Text("Remove the saved API key from Keychain?")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            viewModel.cancelAPIKeyDeletion()
                        }
                        Button("Delete", role: .destructive) {
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
                    statusBadge("Menu Bar", tone: .success)
                } else {
                    Button("Show in Menu Bar") {
                        viewModel.setPrimaryProvider(summary.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            statusBadge(summary.validationStatusText, tone: summary.statusTone)
        }
        .frame(minHeight: 34)
    }

    private func providerAPIHeader(_ summary: APIProviderSummary) -> some View {
        HStack(spacing: 10) {
            providerHomepageButton(summary)

            Spacer()

            Text(summary.apiKeyStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(summary.apiKeyStatusText == "Configured" ? Color.green : Color.secondary)
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
        .padding(.top, 2)
    }

    private func providerMetricItems(for summary: APIProviderSummary) -> [ProviderMetricItem] {
        var metrics = [
            ProviderMetricItem(title: "API Key", value: summary.apiKeyStatusText),
            ProviderMetricItem(title: "Status", value: summary.validationStatusText),
            ProviderMetricItem(title: "Detail", value: summary.balanceText)
        ]

        if let planNextResetText = summary.planNextResetText {
            metrics.append(
                ProviderMetricItem(
                    title: "Plan Next Resets",
                    value: planNextResetText.replacingOccurrences(of: "Plan Next Resets: ", with: "")
                )
            )
        }

        metrics.append(
            ProviderMetricItem(
                title: "Updated",
                value: summary.lastRefreshText.replacingOccurrences(of: "Last updated: ", with: "")
            )
        )

        return metrics
    }

    @ViewBuilder
    private func removeProviderButtonIfNeeded(_ summary: APIProviderSummary) -> some View {
        Button("Remove Provider", role: .destructive) {
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
        .help("Open \(summary.displayName) API page")
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

    private var metricSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 44)
            .padding(.horizontal, 10)
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
    }

    private func statusBadge(_ text: String, tone: ProviderStatusTone) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(statusColor(for: tone))
            .background(statusColor(for: tone).opacity(0.14))
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
