import APIInquiryCore
import AppKit
import SwiftUI

struct ProviderHomepageButton: View {
    let summary: APIProviderSummary
    let strings: LocalizedStrings

    var body: some View {
        Button {
            NSWorkspace.shared.open(summary.homepageURL)
        } label: {
            HStack(spacing: 7) {
                ProviderLogoView(summary: summary)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(height: ConsoleMetrics.providerHomepageButtonHeight)
            .foregroundStyle(Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(strings.openProviderAPIPage(summary.displayName))
    }
}

struct ProviderLogoView: View {
    let summary: APIProviderSummary

    var body: some View {
        if let image = ProviderVisualCatalog.headerLogoTemplate(for: summary.id) {
            let logoSize = ProviderVisualCatalog.consoleLogoSize(for: summary.id)
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
}
