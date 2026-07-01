import APIInquiryCore
import SwiftUI

struct UsageConsoleHomeSection: View {
    let summaries: [APIProviderSummary]
    let strings: LocalizedStrings
    let setPrimaryProvider: (ProviderID) -> Void
    let refreshManualResetCredits: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ConsoleMetrics.homeProviderListSpacing) {
            ForEach(summaries, id: \.id) { summary in
                ProviderStatusRow(
                    summary: summary,
                    strings: strings,
                    setPrimaryProvider: setPrimaryProvider,
                    refreshManualResetCredits: refreshManualResetCredits
                )
            }
        }
    }
}

struct ProviderStatusRow: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let summary: APIProviderSummary
    let strings: LocalizedStrings
    let setPrimaryProvider: (ProviderID) -> Void
    let refreshManualResetCredits: () -> Void

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
            ProviderMetricItem(title: strings.statusMetricTitle, value: summary.validationStatusText),
            ProviderMetricItem(title: strings.detailMetricTitle, value: summary.balanceText)
        ]

        if let planNextResetText = summary.planNextResetText {
            metrics.append(
                ProviderMetricItem(
                    title: strings.planNextResetsMetricTitle,
                    value: strippedPrefix(planNextResetText, prefix: strings.planNextResetsPrefix)
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
            metrics.append(
                ProviderMetricItem(
                    title: strings.manualResetMetricTitle,
                    value: manualResetCreditsText,
                    accessory: ProviderMetricAccessory(
                        systemImageName: "arrow.clockwise",
                        help: strings.refreshManualResetCredits,
                        isDisabled: summary.isManualResetCreditsRefreshing,
                        action: refreshManualResetCredits
                    )
                )
            )
        }

        metrics.append(
            ProviderMetricItem(
                title: strings.updatedMetricTitle,
                value: strippedPrefix(summary.lastRefreshText, prefix: strings.lastUpdatedPrefix)
            )
        )

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

    private func strippedPrefix(_ text: String, prefix: String) -> String {
        if text.hasPrefix("\(prefix): ") {
            return String(text.dropFirst(prefix.count + 2))
        }

        if text.hasPrefix("\(prefix)：") {
            return String(text.dropFirst(prefix.count + 1))
        }

        return text
    }
}
