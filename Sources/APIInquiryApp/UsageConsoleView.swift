import APIInquiryCore
import Foundation
import SwiftUI

struct UsageConsoleView: View {
    @ObservedObject var viewModel: UsageConsoleViewModel
    @State private var selectedSection: UsageConsoleSection
    @State private var replacingProviderIDs: Set<ProviderID> = []
    @State private var providerRemovalConfirmationID: ProviderID?
    @State private var localFeedbacksByProviderID: [ProviderID: SettingsFeedback] = [:]

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
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .home:
            UsageConsoleHomeSection(
                summaries: viewModel.providerSummaries,
                strings: strings,
                setPrimaryProvider: { viewModel.setPrimaryProvider($0) }
            )
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
}
