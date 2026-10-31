import APIInquiryCore
import AppKit
import SwiftUI

struct UsageConsoleSettingsSection: View {
    @Binding var languageSelection: AppLanguage
    let strings: LocalizedStrings
    let appVersionText: String
    /// Set for development builds; tapping the version copies this commit id.
    let developmentCommit: String?

    @State private var didCopyCommit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.languageTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(strings.languageTitle, selection: $languageSelection) {
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

                    versionLabel

                    Button {
                        NSWorkspace.shared.open(ConsoleMetrics.projectHomepageURL)
                    } label: {
                        Label(strings.projectHomepage, systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(strings.projectHomepage)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var versionLabel: some View {
        if let developmentCommit {
            Button {
                copyCommit(developmentCommit)
            } label: {
                Text(didCopyCommit ? strings.commitCopied : appVersionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(didCopyCommit ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .help(strings.copyCommitHint)
            .accessibilityLabel(strings.copyCommitHint)
        } else {
            Text(appVersionText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func copyCommit(_ commit: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commit, forType: .string)
        didCopyCommit = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didCopyCommit = false
        }
    }
}
