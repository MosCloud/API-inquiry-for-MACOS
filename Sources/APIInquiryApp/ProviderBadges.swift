import APIInquiryCore
import SwiftUI

struct ProviderStatusBadge: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

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
            .apiInquirySubtleAnimation(value: healthTone, reduceMotion: accessibilityReduceMotion)
            .apiInquirySubtleAnimation(value: fallbackTone, reduceMotion: accessibilityReduceMotion)
            .transition(.opacity)
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
            .transition(.opacity)
    }
}

struct APIAccessBadge: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let summary: APIProviderSummary
    let strings: LocalizedStrings

    var body: some View {
        let color = ProviderToneColor.apiAccess(summary.apiAccessState)

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
            .apiInquirySubtleAnimation(value: summary.apiAccessState, reduceMotion: accessibilityReduceMotion)
            .transition(.opacity)
    }
}

struct FeedbackText: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let feedback: SettingsFeedback?

    var body: some View {
        Group {
            if let feedback {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: iconName(for: feedback.kind))
                        .font(.caption)
                        .foregroundStyle(ProviderToneColor.feedback(feedback.kind))
                        .accessibilityHidden(true)

                    Text(feedback.message)
                        .font(.caption)
                        .foregroundStyle(ProviderToneColor.feedback(feedback.kind))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .apiInquiryTopChangeTransition(reduceMotion: accessibilityReduceMotion)
            }
        }
        .apiInquirySettingsFeedback(feedback)
        .apiInquirySubtleAnimation(value: feedback, reduceMotion: accessibilityReduceMotion)
    }

    private func iconName(for kind: SettingsFeedbackKind) -> String {
        switch kind {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}
