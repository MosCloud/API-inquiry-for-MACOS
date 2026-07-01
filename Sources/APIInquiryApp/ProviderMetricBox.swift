import SwiftUI

struct ProviderMetricItem {
    let title: String
    let value: String
    let accessory: ProviderMetricAccessory?

    init(title: String, value: String, accessory: ProviderMetricAccessory? = nil) {
        self.title = title
        self.value = value
        self.accessory = accessory
    }
}

struct ProviderMetricAccessory {
    let systemImageName: String
    let help: String
    let isDisabled: Bool
    let action: () -> Void
}

struct ProviderMetricGrid: View {
    let metrics: [ProviderMetricItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics.indices, id: \.self) { index in
                ProviderMetricBox(item: metrics[index])

                if index != metrics.indices.last {
                    metricSeparator
                }
            }
        }
    }

    private var metricSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 8)
    }
}

struct ProviderMetricBox: View {
    let item: ProviderMetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let accessory = item.accessory {
                    ProviderMetricAccessoryButton(accessory: accessory)
                }
            }

            Text(item.value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .accessibilityElement(children: item.accessory == nil ? .combine : .contain)
    }
}

private struct ProviderMetricAccessoryButton: View {
    let accessory: ProviderMetricAccessory

    var body: some View {
        Button(action: accessory.action) {
            Image(systemName: accessory.systemImageName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(accessory.isDisabled)
        .foregroundStyle(.secondary)
        .opacity(accessory.isDisabled ? 0.45 : 0.85)
        .help(accessory.help)
        .accessibilityLabel(accessory.help)
    }
}
