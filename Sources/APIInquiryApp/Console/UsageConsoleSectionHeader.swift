import APIInquiryCore
import SwiftUI

struct UsageConsoleSectionHeader: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @Binding var selectedSection: UsageConsoleSection
    let strings: LocalizedStrings
    let availableProviderIDsToAdd: [ProviderID]
    let displayName: (ProviderID) -> String
    let addProvider: (ProviderID) -> Void
    let refreshFeedback: RefreshActionFeedback
    let refreshTurn: Int
    let canRefresh: Bool
    let refresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(selectedSection.title(strings: strings))
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            if selectedSection == .home {
                refreshButton

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
                .controlSize(.small)
                .disabled(availableProviderIDsToAdd.isEmpty)
                .accessibilityLabel(strings.addProvider)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ConsoleMetrics.sectionHeaderHeight)
    }

    /// Deliberately shaped like the Add Provider control next to it: two
    /// actions of the same rank should look like the same kind of thing
    /// (#109). The icon spins in place so the row never changes width.
    private var refreshButton: some View {
        Button(action: refresh) {
            Label {
                Text(strings.refresh)
            } icon: {
                Image(systemName: refreshFeedback.systemImageName(default: "arrow.clockwise"))
                    .apiInquiryRefreshTurnEffect(
                        turn: refreshFeedback == .refreshing ? refreshTurn : 0,
                        duration: RefreshFeedbackTiming.turnDuration,
                        reduceMotion: accessibilityReduceMotion
                    )
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canRefresh || refreshFeedback.disablesInteraction)
        .accessibilityLabel(strings.refresh)
    }
}
