import APIInquiryCore
import SwiftUI

struct CodexManualResetCreditsDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let model: CodexManualResetCreditsDetailModel
    let strings: LocalizedStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.rows.isEmpty {
                emptyState
            } else {
                detailTable
            }
        }
        .padding(20)
        .frame(minWidth: 640, idealWidth: 640, maxWidth: 640, minHeight: 220, alignment: .topLeading)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(model.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .keyboardShortcut("w", modifiers: .command)
            .accessibilityLabel(strings.close)
        }
    }

    private var emptyState: some View {
        Text(model.emptyText)
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous))
    }

    private var detailTable: some View {
        VStack(spacing: 0) {
            tableHeader
            tableSeparator

            ForEach(model.rows) { row in
                tableRow(row)
                if row.id != model.rows.last?.id {
                    tableSeparator
                }
            }
        }
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ConsoleMetrics.providerRowCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 18) {
            columnHeader(model.grantedAtTitle)
            columnHeader(model.expiresAtTitle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func tableRow(_ row: CodexManualResetCreditDisplayRow) -> some View {
        HStack(spacing: 18) {
            timeText(row.grantedAtText)
            timeText(row.expiresAtText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeText(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced).weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}
