import APIInquiryCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum UsageConsoleSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case usage = "Usage"
    case api = "API"

    var id: String { rawValue }
}

struct UsageConsoleView: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var isReplacingKey = false

    init(viewModel: UsageConsoleViewModel, initialSection: UsageConsoleSection = .overview) {
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

            Divider()

            Group {
                switch selectedSection {
                case .overview:
                    overviewSection
                case .usage:
                    usageSection
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("API Inquiry")
                    .font(.title2.weight(.semibold))
                Text("DeepSeek balance and local usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(viewModel.officialUsageURL)
            } label: {
                Label("DeepSeek Usage", systemImage: "safari")
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                metricBox(title: "API Key", value: viewModel.credentialStatusText)
                metricBox(title: "Records", value: "\(viewModel.usageDataset?.records.count ?? 0)")
                metricBox(title: "Range", value: viewModel.usageDataset?.dateRangeText ?? "--")
            }

            if let totals = viewModel.usageTotals {
                HStack(spacing: 12) {
                    metricBox(title: "Cost", value: "\(formatDecimal(totals.cost)) \(totals.currency)")
                    metricBox(title: "Requests", value: formatInt(totals.requestCount))
                    metricBox(title: "Tokens", value: formatInt(totals.totalTokens))
                }
            } else {
                emptyState("Import a DeepSeek Usage export to see local usage totals.")
            }

            if let metadata = viewModel.usageDataset?.metadata {
                Text("Last import: \(metadata.sourceFileName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button {
                    chooseUsageFile()
                } label: {
                    Label("Import DeepSeek Usage", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    viewModel.clearUsageData()
                } label: {
                    Label("Clear Usage Data", systemImage: "trash")
                }
                .disabled(viewModel.usageDataset == nil)
            }

            feedbackText(viewModel.usageFeedback)

            if viewModel.usageDataset == nil {
                emptyState("Usage data stays on this Mac. Import the zip exported from DeepSeek Usage.")
            } else {
                usageTables
            }
        }
    }

    private var usageTables: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("By Model")
                    .font(.headline)

                tableHeader(columns: ["Model", "Cost", "Tokens"])
                ForEach(viewModel.modelSummaries, id: \.model) { summary in
                    HStack {
                        Text(summary.model)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(formatDecimal(summary.cost)) \(summary.currency)")
                            .frame(width: 110, alignment: .trailing)
                        Text(formatInt(summary.totalTokens))
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Details")
                    .font(.headline)

                tableHeader(columns: ["Date", "Model", "Cost", "Tokens"])
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(viewModel.detailRecords.enumerated()), id: \.offset) { _, record in
                            HStack {
                                Text(formatDate(record.occurredAt))
                                    .frame(width: 82, alignment: .leading)
                                Text(record.model)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(formatDecimal(record.cost)) \(record.currency)")
                                    .frame(width: 100, alignment: .trailing)
                                Text(formatInt(record.totalTokens))
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                        }
                    }
                }
                .frame(minHeight: 260)
            }
        }
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DeepSeek API Key")
                    .font(.headline)
                Spacer()
                Text(viewModel.credentialStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.isAPIKeyConfigured || isReplacingKey {
                SecureField(viewModel.isAPIKeyConfigured ? "New DeepSeek API key" : "DeepSeek API key", text: $viewModel.apiKeyInput)
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
                .padding(10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            feedbackText(viewModel.settingsFeedback)

            Button {
                NSWorkspace.shared.open(viewModel.officialUsageURL)
            } label: {
                Label("Open DeepSeek Usage", systemImage: "safari")
            }
        }
    }

    private func chooseUsageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "zip"),
            UTType(filenameExtension: "csv"),
            .plainText
        ].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importUsageFile(at: url)
        }
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
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tableHeader(columns: [String]) -> some View {
        HStack {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
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

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatInt(_ value: Int) -> String {
        Self.intFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        Self.decimalFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "--"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let intFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter
    }()
}
