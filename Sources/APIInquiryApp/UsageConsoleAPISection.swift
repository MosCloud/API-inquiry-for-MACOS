import APIInquiryCore
import AppKit
import SwiftUI

struct UsageConsoleAPISection: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @Binding var replacingProviderIDs: Set<ProviderID>
    @Binding var providerRemovalConfirmationID: ProviderID?
    @Binding var localFeedbacksByProviderID: [ProviderID: SettingsFeedback]

    var body: some View {
        VStack(alignment: .leading, spacing: ConsoleMetrics.apiProviderListSpacing) {
            ForEach(viewModel.providerSummaries, id: \.id) { summary in
                apiProviderPanel(summary)
            }
        }
    }

    private func apiProviderPanel(_ summary: APIProviderSummary) -> some View {
        let isEditingAPIKey = summary.supportsAPIKeyManagement && replacingProviderIDs.contains(summary.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ProviderHomepageButton(summary: summary, strings: strings)

                HStack(spacing: 8) {
                    APIAccessBadge(summary: summary, strings: strings)

                    Text(summary.apiAccessPurposeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                apiPrimaryAction(summary, isEditingAPIKey: isEditingAPIKey)
                    .fixedSize()
                apiProviderMoreMenu(summary)
                    .fixedSize()
            }

            if isEditingAPIKey {
                HStack(spacing: 8) {
                    SecureField(
                        viewModel.isAPIKeyConfigured(for: summary.id)
                            ? strings.newAPIKeyPlaceholder
                            : strings.apiKeyPlaceholder,
                        text: apiKeyBinding(for: summary.id)
                    )
                    .textFieldStyle(.roundedBorder)

                    Button(strings.cancel) {
                        replacingProviderIDs.remove(summary.id)
                        viewModel.setAPIKeyInput("", for: summary.id)
                    }
                    .controlSize(.small)
                }
            }

            providerRemovalConfirmation(for: summary)
            apiKeyDeletionConfirmation(for: summary)

            FeedbackText(feedback: viewModel.settingsFeedback(for: summary.id))
            FeedbackText(feedback: localFeedbacksByProviderID[summary.id])
        }
        .padding(.horizontal, ConsoleMetrics.providerModuleHorizontalPadding)
        .padding(.vertical, ConsoleMetrics.apiProviderModuleVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: ConsoleMetrics.apiProviderModuleMinHeight, alignment: .leading)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func providerRemovalConfirmation(for summary: APIProviderSummary) -> some View {
        if providerRemovalConfirmationID == summary.id {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    summary.supportsAPIKeyManagement && viewModel.isAPIKeyConfigured(for: summary.id)
                        ? strings.removeProviderAndDeleteAPIKeyConfirmation
                        : strings.removeProviderConfirmation
                )
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
    }

    @ViewBuilder
    private func apiKeyDeletionConfirmation(for summary: APIProviderSummary) -> some View {
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
    }

    @ViewBuilder
    private func apiPrimaryAction(_ summary: APIProviderSummary, isEditingAPIKey: Bool) -> some View {
        if summary.supportsAPIKeyManagement {
            if isEditingAPIKey {
                Button(viewModel.isAPIKeyConfigured(for: summary.id) ? strings.saveReplacement : strings.save) {
                    Task {
                        await viewModel.saveAPIKey(for: summary.id)
                        if viewModel.isAPIKeyConfigured(for: summary.id) {
                            replacingProviderIDs.remove(summary.id)
                        }
                    }
                }
                .disabled(viewModel.apiKeyInput(for: summary.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .font(.system(.callout, design: .rounded).weight(.semibold))
            } else {
                Button(viewModel.isAPIKeyConfigured(for: summary.id) ? strings.replaceKey : strings.configureKey) {
                    replacingProviderIDs.insert(summary.id)
                    viewModel.setAPIKeyInput("", for: summary.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .font(.system(.callout, design: .rounded).weight(.semibold))
            }
        } else if summary.codexConfigTargetURL != nil {
            Button(strings.openConfig) {
                openCodexConfig(summary)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(.system(.callout, design: .rounded).weight(.semibold))
        }
    }

    private func apiProviderMoreMenu(_ summary: APIProviderSummary) -> some View {
        Menu {
            if summary.supportsAPIKeyManagement, viewModel.isAPIKeyConfigured(for: summary.id) {
                Button(strings.deleteKey, role: .destructive) {
                    viewModel.requestAPIKeyDeletion(for: summary.id)
                }
            }

            if !summary.supportsAPIKeyManagement, summary.codexConfigTargetURL != nil {
                Button(strings.showConfigInFinder) {
                    showCodexConfigInFinder(summary)
                }
            }

            Button(strings.removeProvider, role: .destructive) {
                providerRemovalConfirmationID = summary.id
            }
            .disabled(viewModel.providerSummaries.count <= 1)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .help(strings.removeProvider)
        .accessibilityLabel(strings.removeProvider)
    }

    private func openCodexConfig(_ summary: APIProviderSummary) {
        guard let targetURL = summary.codexConfigTargetURL else {
            localFeedbacksByProviderID[summary.id] = SettingsFeedback(
                kind: .error,
                message: strings.configCouldNotBeOpened
            )
            return
        }

        if NSWorkspace.shared.open(targetURL) {
            localFeedbacksByProviderID[summary.id] = nil
        } else {
            localFeedbacksByProviderID[summary.id] = SettingsFeedback(
                kind: .error,
                message: strings.configCouldNotBeOpened
            )
        }
    }

    private func showCodexConfigInFinder(_ summary: APIProviderSummary) {
        guard let targetURL = summary.codexConfigTargetURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        localFeedbacksByProviderID[summary.id] = nil
    }

    private func apiKeyBinding(for id: ProviderID) -> Binding<String> {
        Binding {
            viewModel.apiKeyInput(for: id)
        } set: { value in
            viewModel.setAPIKeyInput(value, for: id)
        }
    }

    private var strings: LocalizedStrings {
        viewModel.localizedStrings
    }
}
