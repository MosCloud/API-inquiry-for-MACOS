import APIInquiryCore
import SwiftUI
import UniformTypeIdentifiers

/// Everything a row needs to take part in reordering, grouped so the row does not
/// grow nine separate parameters.
struct ProviderReorderState {
    let isDragging: Bool
    let isDropTarget: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let startedDragging: () -> Void
    let targeted: (Bool) -> Void
    let dropped: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
}

struct UsageConsoleHomeSection: View {
    let summaries: [APIProviderSummary]
    let strings: LocalizedStrings
    let setPrimaryProvider: (ProviderID) -> Void
    let moveProvider: (ProviderID, Int) -> Void
    let manualResetRefreshFeedback: RefreshActionFeedback
    let manualResetRefreshTurn: Int
    let refreshManualResetCredits: () -> Void
    let showManualResetDetails: () -> Void

    @State private var draggedProviderID: ProviderID?
    @State private var dropTargetID: ProviderID?

    var body: some View {
        VStack(alignment: .leading, spacing: ConsoleMetrics.homeProviderListSpacing) {
            ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                ProviderStatusRow(
                    summary: summary,
                    strings: strings,
                    setPrimaryProvider: setPrimaryProvider,
                    manualResetRefreshFeedback: manualResetRefreshFeedback,
                    manualResetRefreshTurn: manualResetRefreshTurn,
                    refreshManualResetCredits: refreshManualResetCredits,
                    showManualResetDetails: showManualResetDetails,
                    reorder: reorderState(for: summary, at: index)
                )
            }
        }
    }

    /// Dropping on a card moves the dragged provider to that card's position: the
    /// list is short, and "put it where I dropped it" is easier to predict than
    /// tracking an insertion edge on every row.
    private func reorderState(for summary: APIProviderSummary, at index: Int) -> ProviderReorderState {
        ProviderReorderState(
            isDragging: draggedProviderID == summary.id,
            isDropTarget: dropTargetID == summary.id && draggedProviderID != summary.id,
            canMoveUp: summaries.count > 1 && index > 0,
            canMoveDown: summaries.count > 1 && index < summaries.count - 1,
            startedDragging: { draggedProviderID = summary.id },
            targeted: { isInside in
                if isInside {
                    dropTargetID = summary.id
                } else if dropTargetID == summary.id {
                    dropTargetID = nil
                }
            },
            dropped: { finishDrop(on: summary.id, at: index) },
            moveUp: { moveProvider(summary.id, index - 1) },
            moveDown: { moveProvider(summary.id, index + 1) }
        )
    }

    private func finishDrop(on targetID: ProviderID, at index: Int) {
        defer {
            draggedProviderID = nil
            dropTargetID = nil
        }

        guard let draggedProviderID, draggedProviderID != targetID else {
            return
        }
        moveProvider(draggedProviderID, index)
    }
}

struct ProviderStatusRow: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let summary: APIProviderSummary
    let strings: LocalizedStrings
    let setPrimaryProvider: (ProviderID) -> Void
    let manualResetRefreshFeedback: RefreshActionFeedback
    let manualResetRefreshTurn: Int
    let refreshManualResetCredits: () -> Void
    let showManualResetDetails: () -> Void
    let reorder: ProviderReorderState

    var body: some View {
        VStack(alignment: .leading, spacing: ConsoleMetrics.providerHeaderMetricsSpacing) {
            header
            ProviderMetricGrid(metrics: providerMetricItems)
        }
        .padding(.horizontal, ConsoleMetrics.providerModuleHorizontalPadding)
        .padding(.vertical, ConsoleMetrics.providerModuleVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: ConsoleMetrics.providerModuleMinHeight, alignment: .topLeading)
        .background {
            providerRowBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            ProviderReorderGrip(strings: strings, isActive: reorder.isDragging)
                .padding(.trailing, 10)
                .padding(.bottom, 4)
                .onDrag {
                    reorder.startedDragging()
                    return NSItemProvider(object: summary.id.rawValue as NSString)
                }
        }
        .overlay(alignment: .top) {
            if reorder.isDropTarget {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .padding(.horizontal, 6)
                    .offset(y: -1)
            }
        }
        .opacity(reorder.isDragging ? 0.45 : 1)
        .onDrop(
            of: [UTType.text],
            isTargeted: Binding(
                get: { reorder.isDropTarget },
                set: { reorder.targeted($0) }
            )
        ) { _ in
            reorder.dropped()
            return true
        }
        .contextMenu {
            Button(strings.moveUp) { reorder.moveUp() }
                .disabled(!reorder.canMoveUp)
            Button(strings.moveDown) { reorder.moveDown() }
                .disabled(!reorder.canMoveDown)
        }
        .accessibilityAction(named: Text(strings.moveUp)) { reorder.moveUp() }
        .accessibilityAction(named: Text(strings.moveDown)) { reorder.moveDown() }
        .apiInquirySubtleAnimation(value: summary.healthTone, reduceMotion: accessibilityReduceMotion)
        .apiInquirySubtleAnimation(value: summary.statusTone, reduceMotion: accessibilityReduceMotion)
        .apiInquirySubtleAnimation(value: summary.isPrimary, reduceMotion: accessibilityReduceMotion)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ProviderHomepageButton(summary: summary, strings: strings)

            if summary.isPrimary {
                MenuBarBadge(text: strings.menuBar)
            } else {
                Button(strings.showInMenuBar) {
                    setPrimaryProvider(summary.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(strings.showInMenuBar)
            }

            Spacer()

            ProviderStatusBadge(
                text: summary.summaryBadgeText,
                healthTone: summary.healthTone,
                fallbackTone: summary.statusTone
            )
        }
        .frame(minHeight: 34)
    }

    private var providerMetricItems: [ProviderMetricItem] {
        var metrics = [
            ProviderMetricItem(title: strings.apiKeyMetricTitle, value: summary.apiKeyStatusText),
            ProviderMetricItem(title: summary.statusMetricTitle, value: summary.statusMetricValue),
            ProviderMetricItem(
                title: summary.detailMetricTitle,
                value: summary.balanceText,
                detail: summary.totalBalanceDetail
            )
        ]

        if let grantedBalanceText = summary.grantedBalanceText {
            metrics.append(
                ProviderMetricItem(
                    title: summary.grantedBalanceMetricTitle,
                    value: grantedBalanceText,
                    detail: summary.grantedBalanceDetail
                )
            )
        }

        if let planNameText = summary.planNameText {
            metrics.append(
                ProviderMetricItem(
                    title: strings.planMetricTitle,
                    value: planNameText
                )
            )
        }

        if let manualResetCreditsText = summary.manualResetCreditsText {
            let feedback: RefreshActionFeedback = summary.isManualResetCreditsRefreshing
                ? .refreshing
                : manualResetRefreshFeedback
            metrics.append(
                ProviderMetricItem(
                    title: strings.manualResetMetricTitle,
                    value: manualResetCreditsText,
                    accessory: ProviderMetricAccessory(
                        systemImageName: "arrow.clockwise",
                        help: strings.refreshManualResetCredits,
                        feedback: feedback,
                        refreshTurn: manualResetRefreshTurn,
                        action: refreshManualResetCredits
                    ),
                    valueAction: ProviderMetricValueAction(
                        help: strings.showManualResetDetails,
                        action: showManualResetDetails
                    )
                )
            )
        }

        return metrics
    }

    @ViewBuilder
    private var providerRowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous)

        switch summary.healthTone {
        case .neutral:
            shape.fill(Color.secondary.opacity(0.10))
        case .good, .warning, .critical:
            let color = ProviderToneColor.amount(summary.healthTone)
            shape
                .fill(Color.secondary.opacity(0.08))
                .overlay {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: color.opacity(0.07), location: 0),
                                Gradient.Stop(color: color.opacity(0.045), location: 0.28),
                                Gradient.Stop(color: color.opacity(0.018), location: 0.50),
                                Gradient.Stop(color: color.opacity(0), location: 0.65),
                                Gradient.Stop(color: color.opacity(0), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
        }
    }

}
