import APIInquiryCore
import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @Environment(\.dismiss) private var dismissMenu
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @ObservedObject var viewModel: MenuBarBalanceViewModel
    @ObservedObject var languageStore: AppLanguageStore
    @StateObject private var launchAtLoginController: LaunchAtLoginController
    @State private var refreshAnimationTurn = 0
    @State private var refreshAnimationTask: Task<Void, Never>?
    private let openConsole: (UsageConsoleSection) -> Void

    init(
        viewModel: MenuBarBalanceViewModel,
        languageStore: AppLanguageStore,
        openConsole: @escaping (UsageConsoleSection) -> Void
    ) {
        self.viewModel = viewModel
        self.languageStore = languageStore
        self.openConsole = openConsole
        _launchAtLoginController = StateObject(wrappedValue: LaunchAtLoginController(languageStore: languageStore))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if viewModel.primaryDisplayParts.detailKind == .quotaUsage,
               !viewModel.primaryQuotaWindowRows.isEmpty {
                quotaHeroRows
            } else {
                balance
            }
            status
            if let errorText = viewModel.errorText {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.recoveryActions.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(viewModel.recoveryActions, id: \.self) { action in
                                recoveryButton(for: action)
                            }
                        }
                    }
                }
                .apiInquiryTopChangeTransition(reduceMotion: accessibilityReduceMotion)
            }

            Divider()

            if !viewModel.secondaryProviderRows.isEmpty {
                secondaryProviders
                Divider()
            }

            if viewModel.shouldShowSetupGuidance {
                consolePrompt
                Divider()
            }

            if let autoStartMessage = launchAtLoginController.message {
                Text(autoStartMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .apiInquiryTopChangeTransition(reduceMotion: accessibilityReduceMotion)
            }

            footer
        }
        .padding(16)
        .frame(width: 320)
        .apiInquiryMenuBarGlassPanelBackground()
        .onAppear {
            launchAtLoginController.refreshStatus()
            if viewModel.isRefreshDisabled {
                startRefreshAnimationLoop()
            }
        }
        .onDisappear {
            stopRefreshAnimationLoop()
        }
        .onChange(of: accessibilityReduceMotion) { reduceMotion in
            if reduceMotion {
                stopRefreshAnimationLoop()
            } else if viewModel.isRefreshDisabled {
                startRefreshAnimationLoop()
            }
        }
        .onChange(of: viewModel.isRefreshDisabled) { isRefreshing in
            if isRefreshing {
                startRefreshAnimationLoop()
            } else {
                stopRefreshAnimationLoop()
            }
        }
        .apiInquirySubtleAnimation(value: viewModel.errorText, reduceMotion: accessibilityReduceMotion)
        .apiInquirySubtleAnimation(value: launchAtLoginController.message, reduceMotion: accessibilityReduceMotion)
    }

    private var consolePrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.setupGuidanceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openConsoleAndCloseMenu(.api)
            } label: {
                Label(strings.openConsole, systemImage: "macwindow")
            }
            .buttonStyle(.borderless)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            let providerID = viewModel.primaryDisplayParts.providerID
            if let headerLogo = ProviderVisualCatalog.headerLogoTemplate(for: providerID) {
                let logoSize = ProviderVisualCatalog.headerLogoSize(for: providerID)
                Image(nsImage: headerLogo)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: logoSize.width, height: logoSize.height, alignment: .leading)
                    .accessibilityLabel(viewModel.providerDisplayName)
            } else {
                Text(viewModel.providerDisplayName)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            HStack(spacing: 6) {
                headerIconButton(systemImage: "macwindow", help: strings.console) {
                    openConsoleAndCloseMenu(.home)
                }

                headerIconButton(
                    systemImage: "arrow.clockwise",
                    help: viewModel.isRefreshDisabled ? strings.refreshing : strings.refresh,
                    accessibilityLabel: strings.refresh,
                    accessibilityValue: viewModel.isRefreshDisabled ? strings.refreshing : nil,
                    refreshTurn: refreshAnimationTurn,
                    reduceMotion: accessibilityReduceMotion
                ) {
                    startRefreshAnimationLoop()
                    Task { await viewModel.refresh() }
                }
                .disabled(viewModel.isRefreshDisabled)
            }
        }
    }

    @ViewBuilder
    private var balance: some View {
        let parts = viewModel.primaryDisplayParts
        let amountSize: CGFloat = parts.amountText == "--" ? 30 : 42

        Group {
            if parts.detailKind == .planUsage {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    if !parts.captionText.isEmpty {
                        Text(parts.captionText)
                            .font(.system(size: 24, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    balanceAmountLine(parts: parts, amountSize: amountSize)

                    if let resetText = viewModel.resetText {
                        Spacer(minLength: 8)
                        Text(resetText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(minWidth: 86, alignment: .trailing)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if !parts.captionText.isEmpty {
                        Text(parts.captionText)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    balanceAmountLine(parts: parts, amountSize: amountSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func balanceAmountLine(parts: PrimaryProviderDisplayParts, amountSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if !parts.leadingText.isEmpty {
                Text(parts.leadingText)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(parts.amountText)
                .font(.system(size: amountSize, weight: .medium, design: .rounded))
                .foregroundStyle(amountColor(for: parts.amountTone))
                .monospacedDigit()
                .apiInquiryNumericTextTransition(value: parts.amountValue, reduceMotion: accessibilityReduceMotion)
                .fixedSize(horizontal: true, vertical: false)
                .apiInquirySubtleAnimation(value: parts.amountText, reduceMotion: accessibilityReduceMotion)
                .apiInquirySubtleAnimation(value: parts.amountTone, reduceMotion: accessibilityReduceMotion)

            if !parts.trailingText.isEmpty {
                Text(parts.trailingText)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .lineLimit(1)
    }

    private var status: some View {
        return HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
                .apiInquirySubtleAnimation(value: viewModel.statusTone, reduceMotion: accessibilityReduceMotion)

            Spacer()

            Text(viewModel.lastRefreshText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(minWidth: 108, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(strings.currentStatus), \(viewModel.statusText)")
        .accessibilityValue(viewModel.lastRefreshText)
    }

    private var quotaHeroRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.primaryQuotaWindowRows, id: \.label) { row in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(row.label)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 32, alignment: .leading)

                    Text(row.amountText)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundStyle(amountColor(for: row.amountTone))
                        .monospacedDigit()
                        .apiInquiryNumericTextTransition(value: row.amountValue, reduceMotion: accessibilityReduceMotion)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 42, alignment: .trailing)
                        .apiInquirySubtleAnimation(value: row.amountText, reduceMotion: accessibilityReduceMotion)
                        .apiInquirySubtleAnimation(value: row.amountTone, reduceMotion: accessibilityReduceMotion)

                    Text(row.suffixText)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 6)

                    if let resetText = row.resetText {
                        Text(resetText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(minWidth: 82, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(quotaWindowAccessibilityLabel(for: row))
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func recoveryButton(for action: BalanceRecoveryAction) -> some View {
        switch action {
        case .retry:
            Button(strings.retry) {
                Task { await viewModel.refresh() }
            }
            .disabled(viewModel.isRefreshDisabled)
        case .replaceKey, .deleteKey, .openConsole:
            Button(strings.openConsole) {
                openConsoleAndCloseMenu(.api)
            }
        }
    }

    private var secondaryProviders: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.secondaryProviderRows, id: \.providerID) { row in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.displayName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(row.statusText)
                            .font(.caption2)
                            .foregroundStyle(statusColor(for: row.statusTone))
                    }

                    Spacer()

                    secondaryProviderDetail(for: row)
                }
            }
        }
    }

    @ViewBuilder
    private func secondaryProviderDetail(for row: ProviderDetailRow) -> some View {
        if !row.quotaWindowRows.isEmpty {
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(row.quotaWindowRows, id: \.label) { quotaRow in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(quotaRow.label) \(quotaRow.amountText)\(quotaRow.suffixText)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        if let resetText = quotaRow.resetText {
                            Text(resetText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 108, alignment: .trailing)
        } else {
            Group {
                if let resetText = row.resetText {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.detailText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)

                        Text(resetText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(row.detailText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 108, alignment: .trailing)
        }
    }

    private var footer: some View {
        let autoStartDisplay = launchAtLoginController.status.controlDisplay

        return HStack(spacing: 10) {
            footerAction(
                title: strings.autoStart,
                systemImage: autoStartDisplay.systemImageName,
                isHighlighted: autoStartDisplay.isHighlighted
            ) {
                launchAtLoginController.toggle()
            }

            footerAction(title: strings.quit, systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func headerIconButton(
        systemImage: String,
        help: String,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil,
        refreshTurn: Int = 0,
        reduceMotion: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .apiInquiryRefreshTurnEffect(
                    turn: refreshTurn,
                    duration: RefreshAnimation.turnDuration,
                    reduceMotion: reduceMotion
                )
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(accessibilityLabel ?? help)
        .accessibilityValue(accessibilityValue ?? "")
    }

    private func footerAction(
        title: String,
        systemImage: String,
        isHighlighted: Bool = false,
        role: FooterActionRole = .normal,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } icon: {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }
            .labelStyle(.titleAndIcon)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(FooterActionButtonStyle(isHighlighted: isHighlighted, role: role))
        .frame(maxWidth: .infinity)
        .help(title)
    }

    private func openConsoleAndCloseMenu(_ section: UsageConsoleSection) {
        openConsole(section)
        dismissMenu()
    }

    private func startRefreshAnimationLoop() {
        guard !accessibilityReduceMotion else {
            stopRefreshAnimationLoop()
            return
        }

        guard refreshAnimationTask == nil else {
            return
        }

        refreshAnimationTurn += 1
        refreshAnimationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: RefreshAnimation.turnDurationNanoseconds)
                guard !Task.isCancelled else {
                    return
                }

                let shouldContinue = await MainActor.run {
                    !accessibilityReduceMotion && viewModel.isRefreshDisabled
                }
                guard shouldContinue else {
                    await MainActor.run {
                        refreshAnimationTask = nil
                    }
                    return
                }

                await MainActor.run {
                    refreshAnimationTurn += 1
                }
            }
        }
    }

    private func stopRefreshAnimationLoop() {
        refreshAnimationTask?.cancel()
        refreshAnimationTask = nil
    }

    private var statusColor: Color {
        ProviderToneColor.status(viewModel.statusTone)
    }

    private var strings: LocalizedStrings {
        viewModel.localizedStrings
    }

    private func statusColor(for statusTone: ProviderStatusTone) -> Color {
        ProviderToneColor.status(statusTone)
    }

    private func amountColor(for amountTone: ProviderAmountTone) -> Color {
        ProviderToneColor.menuAmount(amountTone)
    }

    private func quotaWindowAccessibilityLabel(for row: QuotaWindowDisplayRow) -> String {
        [
            strings.quotaWindow,
            row.label,
            "\(row.amountText)\(row.suffixText)",
            row.resetText
        ]
        .compactMap { text in
            guard let text, !text.isEmpty else {
                return nil
            }
            return text
        }
        .joined(separator: ", ")
    }
}

private enum RefreshAnimation {
    static let turnDuration = 0.8
    static let turnDurationNanoseconds: UInt64 = 800_000_000
}

private enum FooterActionRole {
    case normal
    case destructive
}

private struct FooterActionButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    let role: FooterActionRole

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var foregroundColor: Color {
        if isHighlighted {
            return .white
        }

        switch role {
        case .normal:
            return .primary
        case .destructive:
            return .red
        }
    }

    private var strokeColor: Color {
        if isHighlighted {
            return Color.accentColor.opacity(0.65)
        }

        switch role {
        case .normal:
            return Color.white.opacity(0.05)
        case .destructive:
            return Color.red.opacity(0.20)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isHighlighted {
            return Color.accentColor.opacity(isPressed ? 0.42 : 0.30)
        }

        switch role {
        case .normal:
            return Color.secondary.opacity(isPressed ? 0.24 : 0.16)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.18 : 0.08)
        }
    }
}
