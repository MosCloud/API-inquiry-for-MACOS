import APIInquiryCore
import Foundation
import SwiftUI

struct UsageConsoleView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var replacingProviderIDs: Set<ProviderID> = []
    @State private var providerRemovalConfirmationID: ProviderID?
    @State private var localFeedbacksByProviderID: [ProviderID: SettingsFeedback] = [:]
    @State private var manualResetRefreshFeedback: RefreshActionFeedback = .idle
    @State private var manualResetRefreshTurn = 0
    @State private var manualResetRefreshAnimationTask: Task<Void, Never>?
    @State private var manualResetRefreshFeedbackResetTask: Task<Void, Never>?

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
                    addProvider: { viewModel.addProvider($0) }
                )

                ScrollView(.vertical) {
                    selectedSectionContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(
            minWidth: 720,
            maxWidth: .infinity,
            minHeight: 520,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .home:
            UsageConsoleHomeSection(
                summaries: viewModel.providerSummaries,
                strings: strings,
                setPrimaryProvider: { viewModel.setPrimaryProvider($0) },
                manualResetRefreshFeedback: manualResetRefreshFeedback,
                manualResetRefreshTurn: manualResetRefreshTurn,
                refreshManualResetCredits: triggerManualResetRefresh
            )
            .onAppear {
                viewModel.refreshCodexManualResetCreditsIfNeeded()
            }
        case .api:
            UsageConsoleAPISection(
                viewModel: viewModel,
                replacingProviderIDs: $replacingProviderIDs,
                providerRemovalConfirmationID: $providerRemovalConfirmationID,
                localFeedbacksByProviderID: $localFeedbacksByProviderID
            )
        case .settings:
            UsageConsoleSettingsSection(
                languageSelection: languageSelectionBinding,
                strings: strings,
                appVersionText: appVersionText
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
        AppVersion.displayVersion
    }

    private func triggerManualResetRefresh() {
        guard manualResetRefreshFeedback == .idle else {
            return
        }

        manualResetRefreshFeedbackResetTask?.cancel()
        manualResetRefreshFeedbackResetTask = nil
        manualResetRefreshFeedback = .refreshing
        startManualResetRefreshAnimationLoop()

        Task {
            let succeeded = await viewModel.refreshCodexManualResetCredits(force: true)
            await MainActor.run {
                completeManualResetRefresh(succeeded: succeeded)
            }
        }
    }

    private func completeManualResetRefresh(succeeded: Bool) {
        stopManualResetRefreshAnimationLoop()
        manualResetRefreshFeedback = succeeded ? .success : .failure
        let targetFeedback = manualResetRefreshFeedback
        manualResetRefreshFeedbackResetTask = Task {
            try? await Task.sleep(nanoseconds: RefreshFeedbackTiming.completionDurationNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard manualResetRefreshFeedback == targetFeedback else {
                    return
                }
                manualResetRefreshFeedback = .idle
                manualResetRefreshFeedbackResetTask = nil
            }
        }
    }

    private func startManualResetRefreshAnimationLoop() {
        guard !accessibilityReduceMotion else {
            stopManualResetRefreshAnimationLoop()
            return
        }

        guard manualResetRefreshAnimationTask == nil else {
            return
        }

        manualResetRefreshTurn += 1
        manualResetRefreshAnimationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: RefreshFeedbackTiming.turnDurationNanoseconds)
                guard !Task.isCancelled else {
                    return
                }

                let shouldContinue = await MainActor.run {
                    !accessibilityReduceMotion && manualResetRefreshFeedback == .refreshing
                }
                guard shouldContinue else {
                    await MainActor.run {
                        manualResetRefreshAnimationTask = nil
                    }
                    return
                }

                await MainActor.run {
                    manualResetRefreshTurn += 1
                }
            }
        }
    }

    private func stopManualResetRefreshAnimationLoop() {
        manualResetRefreshAnimationTask?.cancel()
        manualResetRefreshAnimationTask = nil
    }
}
