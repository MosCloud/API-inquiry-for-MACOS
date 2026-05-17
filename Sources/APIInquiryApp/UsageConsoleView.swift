import APIInquiryCore
import SwiftUI

enum UsageConsoleSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case api = "API"

    var id: String { rawValue }
}

struct UsageConsoleView: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var isReplacingKey = false

    init(viewModel: UsageConsoleViewModel, initialSection: UsageConsoleSection = .home) {
        self.viewModel = viewModel
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("Section", selection: $selectedSection) {
                ForEach(UsageConsoleSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)

            Divider()

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

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("API Inquiry")
                .font(.title2.weight(.semibold))
            Text("API provider status and keys")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var homeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Providers")
                    .font(.headline)

                Spacer()

                Button {
                    selectedSection = .api
                } label: {
                    Label("Add Provider", systemImage: "plus")
                }
            }

            ForEach(viewModel.providerSummaries, id: \.displayName) { summary in
                providerStatusRow(summary)
            }
        }
    }

    private func providerStatusRow(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.displayName)
                    .font(.title3.weight(.semibold))

                Spacer()

                statusBadge(summary.validationStatusText)
            }

            HStack(spacing: 12) {
                metricBox(title: "API Key", value: summary.apiKeyStatusText)
                metricBox(title: "Status", value: summary.validationStatusText)
                metricBox(title: "Balance", value: summary.balanceText)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API Providers")
                .font(.headline)

            ForEach(viewModel.providerSummaries, id: \.displayName) { summary in
                apiProviderPanel(summary)
            }
        }
    }

    private func apiProviderPanel(_ summary: APIProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.displayName)
                        .font(.headline)
                    Text(summary.validationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(summary.apiKeyStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.isAPIKeyConfigured || isReplacingKey {
                SecureField(viewModel.isAPIKeyConfigured ? "New API key" : "API key", text: $viewModel.apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button(viewModel.isAPIKeyConfigured ? "Save Replacement" : "Save") {
                        Task {
                            await viewModel.saveAPIKey()
                            if viewModel.isAPIKeyConfigured {
                                isReplacingKey = false
                            }
                        }
                    }
                    .disabled(viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isReplacingKey {
                        Button("Cancel") {
                            isReplacingKey = false
                            viewModel.apiKeyInput = ""
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Button("Replace Key") {
                        isReplacingKey = true
                        viewModel.beginReplacingAPIKey()
                    }

                    Button("Delete Key", role: .destructive) {
                        viewModel.requestAPIKeyDeletion()
                    }
                }
            }

            if viewModel.isAPIKeyDeleteConfirmationPresented {
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
                                isReplacingKey = false
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            feedbackText(viewModel.settingsFeedback)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(statusColor(for: text))
            .background(statusColor(for: text).opacity(0.14))
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

    private func statusColor(for text: String) -> Color {
        switch text {
        case "Active":
            return .green
        case "Checking":
            return .blue
        case "Invalid", "Unavailable", "Insufficient balance":
            return .orange
        default:
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
