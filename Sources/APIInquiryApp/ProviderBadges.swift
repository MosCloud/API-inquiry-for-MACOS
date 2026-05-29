import APIInquiryCore
import SwiftUI

struct ProviderStatusBadge: View {
    let text: String
    let healthTone: ProviderAmountTone
    let fallbackTone: ProviderStatusTone

    var body: some View {
        let color = healthTone == .neutral
            ? ProviderToneColor.status(fallbackTone)
            : ProviderToneColor.amount(healthTone)

        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

struct MenuBarBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(Color.white)
            .background(Color.accentColor.opacity(0.30))
            .overlay(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

struct APIAccessBadge: View {
    let summary: APIProviderSummary
    let strings: LocalizedStrings

    var body: some View {
        let isLoaded = summary.apiAccessStatusText == strings.configured
            || summary.apiAccessStatusText == strings.loaded
        let color = ProviderToneColor.apiAccess(isLoaded: isLoaded)

        Text(summary.apiAccessStatusText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(summary.apiAccessStatusText)
    }
}

struct FeedbackText: View {
    let feedback: SettingsFeedback?

    var body: some View {
        if let feedback {
            Text(feedback.message)
                .font(.caption)
                .foregroundStyle(ProviderToneColor.feedback(feedback.kind))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
