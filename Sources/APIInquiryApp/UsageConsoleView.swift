import APIInquiryCore
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

struct UsageConsoleView: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var isReplacingKey = false

    init(viewModel: UsageConsoleViewModel, initialSection: UsageConsoleSection = .home) {
        self.viewModel = viewModel
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundAppIcon

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var topNavigation: some View {
        HStack {
            HStack(spacing: 4) {
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
                        .frame(width: 118)
                        .padding(.vertical, 9)
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
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundAppIcon: some View {
        GeometryReader { proxy in
            let markSize = min(max(proxy.size.width * 0.038, CGFloat(40)), CGFloat(50))
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ConsoleBrandMark()
                        .frame(width: markSize, height: markSize)
                        .padding(.trailing, 22)
                        .padding(.bottom, 20)
                }
            }
        }
        .allowsHitTesting(false)
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

private struct ConsoleBrandMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let markColor = Color.primary.opacity(0.24)

            ZStack(alignment: .bottomTrailing) {
                WhaleMarkShape()
                    .fill(markColor)
                    .frame(width: size * 0.78, height: size * 0.72)
                    .offset(x: -size * 0.08, y: -size * 0.10)

                HStack(alignment: .bottom, spacing: size * 0.055) {
                    ForEach(Array([0.34, 0.54, 0.74].enumerated()), id: \.offset) { _, heightFactor in
                        RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                            .fill(markColor)
                            .frame(width: size * 0.105, height: size * heightFactor)
                    }
                }
                .frame(height: size * 0.34, alignment: .bottom)
                .offset(x: -size * 0.02, y: -size * 0.03)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }
}

private struct WhaleMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 100,
                y: rect.minY + rect.height * y / 100
            )
        }

        var path = Path()
        path.move(to: point(9, 60))
        path.addCurve(to: point(29, 28), control1: point(9, 43), control2: point(18, 30))
        path.addCurve(to: point(53, 29), control1: point(38, 25), control2: point(46, 27))
        path.addCurve(to: point(69, 42), control1: point(61, 30), control2: point(66, 36))
        path.addCurve(to: point(86, 36), control1: point(78, 45), control2: point(82, 39))
        path.addCurve(to: point(94, 43), control1: point(90, 33), control2: point(94, 36))
        path.addCurve(to: point(82, 60), control1: point(94, 51), control2: point(90, 57))
        path.addCurve(to: point(69, 63), control1: point(77, 62), control2: point(73, 63))
        path.addCurve(to: point(58, 72), control1: point(66, 69), control2: point(62, 72))
        path.addCurve(to: point(41, 70), control1: point(51, 74), control2: point(46, 72))
        path.addCurve(to: point(22, 76), control1: point(34, 74), control2: point(28, 77))
        path.addCurve(to: point(10, 66), control1: point(15, 75), control2: point(11, 70))
        path.addCurve(to: point(9, 60), control1: point(10, 64), control2: point(9, 62))
        path.closeSubpath()

        path.move(to: point(48, 56))
        path.addCurve(to: point(57, 67), control1: point(52, 59), control2: point(55, 63))
        path.addCurve(to: point(43, 65), control1: point(52, 69), control2: point(47, 68))
        path.addCurve(to: point(36, 55), control1: point(39, 61), control2: point(37, 58))
        path.addCurve(to: point(48, 56), control1: point(40, 54), control2: point(44, 54))
        path.closeSubpath()

        return path
    }
}
