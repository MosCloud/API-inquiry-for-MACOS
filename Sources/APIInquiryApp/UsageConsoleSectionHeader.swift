import APIInquiryCore
import SwiftUI

struct UsageConsoleSectionHeader: View {
    @Binding var selectedSection: UsageConsoleSection
    let strings: LocalizedStrings
    let availableProviderIDsToAdd: [ProviderID]
    let displayName: (ProviderID) -> String
    let addProvider: (ProviderID) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(selectedSection.title(strings: strings))
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            if selectedSection == .home {
                Menu {
                    ForEach(availableProviderIDsToAdd, id: \.self) { id in
                        Button(displayName(id)) {
                            addProvider(id)
                            selectedSection = .api
                        }
                    }
                } label: {
                    Label(strings.addProvider, systemImage: "plus")
                }
                .disabled(availableProviderIDsToAdd.isEmpty)
                .help(strings.addProvider)
                .accessibilityLabel(strings.addProvider)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ConsoleMetrics.sectionHeaderHeight)
    }
}
