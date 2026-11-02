import APIInquiryCore
import Foundation
import SwiftUI

struct UsageConsoleView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var replacingProviderIDs: Set<ProviderID> = []
    @State private var providerRemovalConfirmationID: ProviderID?
    @StateObject private var manualResetRefreshFeedbackController = RefreshActionFeedbackController()
    @StateObject private var refreshAllFeedbackController = RefreshActionFeedbackController()
    @State private var isManualResetDetailsPresented = false

    init(viewModel: UsageConsoleViewModel, initialSection: UsageConsoleSection = .home) {
        self.viewModel = viewModel
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            UsageConsoleNavigationView(
                selectedSection: $selectedSection,
                strings: strings
            )

            VStack(alignment: .leading, spacing: 14) {
                UsageConsoleSectionHeader(
                    selectedSection: $selectedSection,
                    strings: strings,
                    availableProviderIDsToAdd: viewModel.availableProviderIDsToAdd,
                    displayName: { viewModel.displayName(for: $0) },
                    addProvider: { viewModel.addProvider($0) },
                    refreshFeedback: refreshAllFeedbackController.feedback,
                    refreshTurn: refreshAllFeedbackController.refreshTurn,
                    canRefresh: !viewModel.providerSummaries.isEmpty,
                    refresh: triggerRefreshAll
                )

                ScrollView(.vertical) {
                    // The content reserves the scroller's width, and the scroll view
                    // bleeds exactly that much into the window margin. The cards keep
                    // their 20 pt margin on both sides, and the scroller lives in the
                    // right margin instead of on top of a card (#114). Padding has to
                    // come before the flexible frame: applied afterwards it pads
                    // outside the full-width frame and changes nothing.
                    selectedSectionContent
                        .padding(.trailing, ConsoleMetrics.scrollerGutter)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.trailing, -ConsoleMetrics.scrollerGutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(
            minWidth: ConsoleMetrics.windowMinWidth,
            maxWidth: .infinity,
            minHeight: ConsoleMetrics.windowMinHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.regularMaterial)
        .sheet(isPresented: $isManualResetDetailsPresented) {
            CodexManualResetCreditsDetailSheet(
                model: viewModel.codexManualResetCreditsDetailModel,
                strings: strings
            )
        }
        .onChange(of: accessibilityReduceMotion) { reduceMotion in
            manualResetRefreshFeedbackController.syncExternalRefreshing(false, reduceMotion: reduceMotion)
        }
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .home:
            UsageConsoleHomeSection(
                summaries: viewModel.providerSummaries,
                strings: strings,
                setPrimaryProvider: { viewModel.setPrimaryProvider($0) },
                manualResetRefreshFeedback: manualResetRefreshFeedbackController.feedback,
                manualResetRefreshTurn: manualResetRefreshFeedbackController.refreshTurn,
                refreshManualResetCredits: triggerManualResetRefresh,
                showManualResetDetails: {
                    isManualResetDetailsPresented = true
                }
            )
            .onAppear {
                viewModel.refreshCodexManualResetCreditsIfNeeded()
            }
        case .api:
            UsageConsoleAPISection(
                viewModel: viewModel,
                replacingProviderIDs: $replacingProviderIDs,
                providerRemovalConfirmationID: $providerRemovalConfirmationID
            )
        case .settings:
            UsageConsoleSettingsSection(
                languageSelection: languageSelectionBinding,
                strings: strings,
                appVersionText: appVersionText,
                developmentCommit: AppVersion.identity.developmentCommit
            )
        }
    }

    private var languageSelectionBinding: Binding<AppLanguage> {
        Binding {
            viewModel.languageSelection
        } set: { value in
            viewModel.languageSelection = value
        }
    }

    private var strings: LocalizedStrings {
        viewModel.localizedStrings
    }

    private var appVersionText: String {
        AppVersion.identity.displayText(using: strings)
    }

    /// Spins only while the work is in flight: providers fail individually and
    /// the cards already say so, so a green tick here would have to lie about
    /// the ones that failed.
    private func triggerRefreshAll() {
        guard refreshAllFeedbackController.begin(reduceMotion: accessibilityReduceMotion) else {
            return
        }

        let refreshesManualResetCredits = viewModel.providerSummaries.contains {
            $0.id == .codex && $0.manualResetCreditsText != nil
        }
        if refreshesManualResetCredits {
            manualResetRefreshFeedbackController.syncExternalRefreshing(
                true,
                reduceMotion: accessibilityReduceMotion
            )
        }

        Task {
            await viewModel.refreshAll()
            await MainActor.run {
                refreshAllFeedbackController.reset()
                if refreshesManualResetCredits {
                    manualResetRefreshFeedbackController.syncExternalRefreshing(
                        false,
                        reduceMotion: accessibilityReduceMotion
                    )
                }
            }
        }
    }

    private func triggerManualResetRefresh() {
        guard manualResetRefreshFeedbackController.begin(reduceMotion: accessibilityReduceMotion) else {
            return
        }

        Task {
            let succeeded = await viewModel.refreshCodexManualResetCredits(force: true)
            await MainActor.run {
                manualResetRefreshFeedbackController.complete(succeeded: succeeded)
            }
        }
    }
}
