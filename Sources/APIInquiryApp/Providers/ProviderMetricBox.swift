import SwiftUI

struct ProviderMetricItem {
    let title: String
    let value: String
    let accessory: ProviderMetricAccessory?
    let valueAction: ProviderMetricValueAction?

    init(
        title: String,
        value: String,
        accessory: ProviderMetricAccessory? = nil,
        valueAction: ProviderMetricValueAction? = nil
    ) {
        self.title = title
        self.value = value
        self.accessory = accessory
        self.valueAction = valueAction
    }
}

struct ProviderMetricAccessory {
    let systemImageName: String
    let help: String
    let feedback: RefreshActionFeedback
    let refreshTurn: Int
    let action: () -> Void
}

struct ProviderMetricValueAction {
    let help: String
    let action: () -> Void
}

struct ProviderMetricGrid: View {
    let metrics: [ProviderMetricItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics.indices, id: \.self) { index in
                ProviderMetricBox(item: metrics[index])

                if index != metrics.indices.last {
                    ProviderMetricSeparator()
                }
            }
        }
    }
}

struct ProviderMetricSeparator: View {
    var body: some View {
        Rectangle()
            .fill(ConsoleSurfaceColor.separator)
            .frame(width: 1, height: 36)
            .padding(.horizontal, 8)
    }
}

struct ProviderMetricBox: View {
    let item: ProviderMetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let accessory = item.accessory {
                    ProviderMetricAccessoryButton(accessory: accessory)
                }
            }
            .frame(height: 14, alignment: .center)

            valueView
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .accessibilityElement(children: item.accessory == nil ? .combine : .contain)
    }

    @ViewBuilder
    private var valueView: some View {
        if let valueAction = item.valueAction {
            Button(action: valueAction.action) {
                metricValueText
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(ConsoleSurfaceColor.subtleStroke, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.value)
            .accessibilityHint(valueAction.help)
        } else {
            metricValueText
        }
    }

    private var metricValueText: some View {
        Text(item.value)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct ProviderMetricAccessoryButton: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let accessory: ProviderMetricAccessory

    var body: some View {
        Button(action: accessory.action) {
            Image(systemName: accessory.feedback.systemImageName(default: accessory.systemImageName))
                .font(.system(size: 9, weight: .semibold))
                .apiInquiryRefreshTurnEffect(
                    turn: accessory.feedback == .refreshing ? accessory.refreshTurn : 0,
                    duration: RefreshFeedbackTiming.turnDuration,
                    reduceMotion: accessibilityReduceMotion
                )
                .scaleEffect(accessory.feedback.isCompletion && !accessibilityReduceMotion ? 1.05 : 1)
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
                .id(accessory.feedback)
        }
        .buttonStyle(.plain)
        .frame(width: 14, height: 14)
        .disabled(accessory.feedback.disablesInteraction)
        .foregroundStyle(accessory.feedback.foregroundColor)
        .opacity(accessory.feedback == .refreshing ? 0.75 : 0.9)
        .accessibilityLabel(accessory.help)
        .apiInquirySubtleAnimation(value: accessory.feedback, reduceMotion: accessibilityReduceMotion)
    }
}
