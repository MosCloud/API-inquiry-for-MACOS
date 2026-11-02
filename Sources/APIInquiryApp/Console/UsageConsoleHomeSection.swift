import APIInquiryCore
import SwiftUI
import UniformTypeIdentifiers

/// Everything a row needs to take part in reordering, grouped so the row does not
/// grow nine separate parameters.
struct ProviderReorderState {
    let isDragging: Bool
    /// True on every other card while a card is in the air, so the list can step
    /// back and let the lifted card read as the one being held.
    let isBackground: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let startedDragging: () -> Void
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
    @State private var rowFrames: [ProviderID: CGRect] = [:]
    @State private var dragWatchTask: Task<Void, Never>?
    @State private var autoScroller = DragAutoScroller()
    @State private var autoScrollTask: Task<Void, Never>?
    /// Where the pointer is in list coordinates. Drop events report it directly;
    /// while the list scrolls under a still pointer, this is what the scroll
    /// delta gets added to.
    @State private var pointerListY: CGFloat = 0

    private static let listSpace = "providerReorderList"

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
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ProviderRowFramePreferenceKey.self,
                            value: [summary.id: proxy.frame(in: .named(Self.listSpace))]
                        )
                    }
                }
            }
        }
        .coordinateSpace(name: Self.listSpace)
        .background {
            ScrollViewResolver { scrollView in
                autoScroller.attach(scrollView)
            }
            .frame(width: 0, height: 0)
        }
        .onPreferenceChange(ProviderRowFramePreferenceKey.self) { frames in
            rowFrames = frames
        }
        .onDrop(of: [UTType.text], delegate: dropDelegate)
    }

    /// Dropping on a card moves the dragged provider to that card's position: the
    /// list is short, and "put it where I dropped it" is easier to predict than
    /// tracking an insertion edge on every row.
    /// One spring for every step of the gesture, so a card lifts, the others make
    /// room, and the drop settles without changing rhythm halfway through.
    static let reorderAnimation = Animation.spring(response: 0.30, dampingFraction: 0.78)
    static let liftAnimation = Animation.spring(response: 0.22, dampingFraction: 0.72)

    /// A drop only arrives when the release lands on a card. Releasing anywhere
    /// else - the header, the window frame, another app - is a cancelled drag the
    /// system never reports, which left the card stuck in its lifted state. The
    /// mouse button is the one signal that covers every ending.
    private func watchForDragEnd() {
        dragWatchTask?.cancel()
        dragWatchTask = Task { @MainActor in
            while !Task.isCancelled, NSEvent.pressedMouseButtons != 0 {
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
            guard !Task.isCancelled else {
                return
            }
            finishDragging()
        }
    }

    private func finishDragging() {
        dragWatchTask?.cancel()
        dragWatchTask = nil
        autoScrollTask?.cancel()
        autoScrollTask = nil
        withAnimation(Self.reorderAnimation) {
            draggedProviderID = nil
        }
    }

    private var dropDelegate: ProviderReorderDropDelegate {
        ProviderReorderDropDelegate(
            pointerMoved: { location in
                pointerListY = location.y
                moveProviderIfNeeded(toListY: location.y)
            },
            finish: finishDragging
        )
    }

    /// One place decides where the dragged card belongs, whether the pointer moved
    /// or the list scrolled underneath it.
    private func moveProviderIfNeeded(toListY y: CGFloat) {
        guard let draggedProviderID,
              let currentIndex = summaries.firstIndex(where: { $0.id == draggedProviderID }),
              let targetIndex = summaries.firstIndex(where: { summary in
                  guard let frame = rowFrames[summary.id] else { return false }
                  return y >= frame.minY && y <= frame.maxY
              }),
              targetIndex != currentIndex else {
            return
        }

        withAnimation(Self.reorderAnimation) {
            moveProvider(draggedProviderID, targetIndex)
        }
    }

    /// Auto-scroll has to keep running while the pointer is still, so it cannot
    /// piggyback on drop events: a timer nudges the list and replays the target
    /// decision with the corrected pointer position.
    private func startAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = Task { @MainActor in
            var lastTick = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard !Task.isCancelled else { return }
                guard draggedProviderID != nil else { return }

                let now = Date()
                let deltaTime = now.timeIntervalSince(lastTick)
                lastTick = now

                let delta = autoScroller.tick(deltaTime: deltaTime)
                guard delta != 0 else { continue }
                // Content moved up by `delta`, so the same screen point now sits
                // `delta` further down the list.
                pointerListY += delta
                moveProviderIfNeeded(toListY: pointerListY)
            }
        }
    }

    private func reorderState(for summary: APIProviderSummary, at index: Int) -> ProviderReorderState {
        ProviderReorderState(
            isDragging: draggedProviderID == summary.id,
            isBackground: draggedProviderID != nil && draggedProviderID != summary.id,
            canMoveUp: summaries.count > 1 && index > 0,
            canMoveDown: summaries.count > 1 && index < summaries.count - 1,
            startedDragging: {
                withAnimation(Self.liftAnimation) {
                    draggedProviderID = summary.id
                }
                watchForDragEnd()
                startAutoScroll()
            },
            moveUp: {
                withAnimation(Self.reorderAnimation) { moveProvider(summary.id, index - 1) }
            },
            moveDown: {
                withAnimation(Self.reorderAnimation) { moveProvider(summary.id, index + 1) }
            }
        )
    }
}

/// One drop target for the whole list, indexed by where the pointer is rather than
/// by which card reports `isTargeted`. A card that has just slid out from under the
/// pointer reports a hit again, so per-row targets made the list hop several times
/// in the same gesture - the flicker reported in #110.
private struct ProviderReorderDropDelegate: DropDelegate {
    let pointerMoved: (CGPoint) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        pointerMoved(info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        pointerMoved(info.location)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        finish()
        return true
    }
}

private struct ProviderRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ProviderID: CGRect] = [:]

    static func reduce(value: inout [ProviderID: CGRect], nextValue: () -> [ProviderID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
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
        .clipShape(rowShape)
        .overlay(alignment: .bottomTrailing) {
            ProviderReorderGrip(strings: strings, isActive: reorder.isDragging)
                .padding(.trailing, 10)
                .padding(.bottom, 4)
                .onDrag {
                    reorder.startedDragging()
                    return NSItemProvider(object: summary.id.rawValue as NSString)
                }
        }
        // No scale and no box shadow while the card is held: both are resolved in a
        // different coordinate space than the clip shape, and the card came out with
        // square corners. A short, rounded shadow keeps the lift without touching the
        // plate's geometry (#110).
        .background {
            if reorder.isDragging {
                rowShape
                    .fill(Color.black.opacity(0.38))
                    .blur(radius: 9)
                    .offset(y: 4)
            }
        }
        .blur(radius: reorder.isBackground ? 1.2 : 0)
        .opacity(reorder.isBackground ? 0.75 : 1)
        .zIndex(reorder.isDragging ? 1 : 0)
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

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous)
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
