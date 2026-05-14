import APIInquiryCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarBalanceViewModel

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

            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: DeepSeekImages.headerLogoTemplate)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 156, height: 33, alignment: .leading)
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
        Text(viewModel.panelBalanceText)
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: some View {
        HStack(spacing: 8) {
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
        HStack(spacing: 8) {
            Button {
                NSWorkspace.shared.open(viewModel.consoleURL)
            } label: {
                Label("Open Console", systemImage: "safari")
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
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
