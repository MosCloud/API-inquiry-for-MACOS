import APIInquiryCore
import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarBalanceViewModel
    @StateObject private var launchAtLoginController: LaunchAtLoginController

    init(viewModel: MenuBarBalanceViewModel) {
        self.viewModel = viewModel
        _launchAtLoginController = StateObject(wrappedValue: LaunchAtLoginController())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            balance
            status
            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            apiKeySection

            Divider()

            if let autoStartMessage = launchAtLoginController.message {
                Text(autoStartMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            launchAtLoginController.refreshStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: DeepSeekImages.headerLogoTemplate)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 96, height: 21, alignment: .leading)
                .accessibilityLabel(viewModel.providerDisplayName)

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    private var balance: some View {
        let parts = viewModel.panelBalanceDisplayParts
        let amountSize: CGFloat = parts.amountText == "--" ? 30 : 52

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if !parts.leadingText.isEmpty {
                Text(parts.leadingText)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
            }

            Text(parts.amountText)
                .font(.system(size: amountSize, weight: .medium, design: .rounded))
                .monospacedDigit()

            if !parts.trailingText.isEmpty {
                Text(parts.trailingText)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .padding(.leading, 2)
            }
        }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: some View {
        return HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(viewModel.lastRefreshText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("API Key")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(viewModel.credentialStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isAPIKeyConfigured {
                    Button {
                        viewModel.toggleAPIKeyEditor()
                    } label: {
                        Image(systemName: viewModel.shouldShowAPIKeyEditor ? "chevron.down" : "chevron.right")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help(viewModel.shouldShowAPIKeyEditor ? "Hide API key controls" : "Show API key controls")
                }
            }

            if viewModel.shouldShowAPIKeyEditor {
                SecureField(viewModel.isAPIKeyConfigured ? "New DeepSeek API key" : "DeepSeek API key", text: $viewModel.apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button(viewModel.isAPIKeyConfigured ? "Replace" : "Save") {
                        Task { await viewModel.saveAPIKey() }
                    }
                    .disabled(viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if viewModel.isAPIKeyConfigured {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteAPIKey() }
                        }
                    }
                }

                if let settingsMessage = viewModel.settingsMessage {
                    Text(settingsMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        let autoStartDisplay = launchAtLoginController.status.controlDisplay

        return HStack(spacing: 8) {
            footerAction(
                title: autoStartDisplay.title,
                systemImage: autoStartDisplay.systemImageName,
                isHighlighted: autoStartDisplay.isHighlighted
            ) {
                launchAtLoginController.toggle()
            }

            footerAction(title: "Console", systemImage: "safari") {
                NSWorkspace.shared.open(viewModel.consoleURL)
            }

            footerAction(title: "Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func footerAction(
        title: String,
        systemImage: String,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } icon: {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }
            .labelStyle(.titleAndIcon)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(FooterActionButtonStyle(isHighlighted: isHighlighted))
        .frame(maxWidth: .infinity)
        .help(title)
    }

    private var statusColor: Color {
        switch viewModel.statusText {
        case "Available":
            return .green
        case "Refreshing":
            return .blue
        case "Balance insufficient", "Refresh failed":
            return .orange
        default:
            return .secondary
        }
    }
}

private struct FooterActionButtonStyle: ButtonStyle {
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .foregroundStyle(isHighlighted ? Color.white : Color.primary)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isHighlighted ? Color.accentColor.opacity(0.65) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isHighlighted {
            return Color.accentColor.opacity(isPressed ? 0.42 : 0.30)
        }

        return Color.secondary.opacity(isPressed ? 0.24 : 0.16)
    }
}
