import APIInquiryCore
import SwiftUI

struct UsageConsoleNavigationView: View {
    @Binding var selectedSection: UsageConsoleSection
    let strings: LocalizedStrings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(UsageConsoleSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(
                                width: ConsoleMetrics.navigationIconSize,
                                height: ConsoleMetrics.navigationIconSize
                            )

                        Text(section.displayName(strings: strings))
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: ConsoleMetrics.navigationButtonHeight)
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
                        .stroke(
                            section == selectedSection
                                ? ConsoleSurfaceColor.selectedStroke
                                : ConsoleSurfaceColor.subtleStroke
                        )
                }
                .accessibilityLabel(section.displayName(strings: strings))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: ConsoleMetrics.navigationHeight)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
