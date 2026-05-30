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
                    .contentShape(
                        RoundedRectangle(cornerRadius: ConsoleMetrics.navigationCornerRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .background {
                    ConsoleNavigationSelectionBackground(isSelected: section == selectedSection)
                }
                .help(section.displayName(strings: strings))
                .accessibilityLabel(section.displayName(strings: strings))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: ConsoleMetrics.navigationHeight)
        .background {
            ConsoleNavigationBackground()
        }
        .clipShape(
            RoundedRectangle(cornerRadius: ConsoleMetrics.navigationCornerRadius, style: .continuous)
        )
    }
}
