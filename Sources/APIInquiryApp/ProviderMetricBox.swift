import SwiftUI

struct ProviderMetricItem {
    let title: String
    let value: String
}

struct ProviderMetricGrid: View {
    let metrics: [ProviderMetricItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(metrics.indices, id: \.self) { index in
                ProviderMetricBox(title: metrics[index].title, value: metrics[index].value)

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
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
