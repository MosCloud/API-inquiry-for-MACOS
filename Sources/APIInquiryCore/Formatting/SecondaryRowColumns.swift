import Foundation

/// Column widths for the secondary provider grid.
///
/// The rows used to share one fixed width, which had to fit the widest possible money value
/// (`¥1,234.56`) even when every row was a short percentage. Instead, fit the columns to the
/// content actually on screen and clamp them: compact by default, widening only when a value
/// needs the room, and never past the point where the row would crowd the provider name.
public struct SecondaryRowColumnWidths: Equatable {
    public let label: Double
    public let value: Double
    public let trailing: Double

    /// Breathing room around measured text. Font metrics from AppKit and the glyphs SwiftUI
    /// actually draws disagree slightly (tabular digits are a little wider), so the padding
    /// is deliberately generous: a column that is 3pt too wide is invisible, one that is 1pt
    /// too narrow ellipsizes the value.
    static let textPadding: Double = 6

    /// Below this a percentage column would look cramped; above it, the name column starts
    /// losing space on a 320pt panel.
    static let labelRange: ClosedRange<Double> = 24...46
    static let valueRange: ClosedRange<Double> = 26...72
    static let trailingRange: ClosedRange<Double> = 24...44

    public init(label: Double, value: Double, trailing: Double) {
        self.label = label
        self.value = value
        self.trailing = trailing
    }

    /// - Parameters:
    ///   - label: measured widths of `余额` / `5 时` style labels.
    ///   - value: measured widths of `72%` / `¥68.65` style values.
    ///   - trailing: measured widths of `15:27` / `CNY` style trailing cells.
    public static func fit(
        label: [Double],
        value: [Double],
        trailing: [Double]
    ) -> SecondaryRowColumnWidths {
        SecondaryRowColumnWidths(
            label: clamp(label.max(), to: labelRange),
            value: clamp(value.max(), to: valueRange),
            // An all-empty trailing column collapses instead of holding its 24 pt floor: on
            // a real WorkBuddy account with no monthly package there is no refresh date, and
            // the reserved empty cell pushed the credits value visibly off the right edge
            // (#124). One dated row keeps the column for every row, so alignment survives.
            trailing: clampAllowingCollapse(trailing.max(), to: trailingRange)
        )
    }

    private static func clampAllowingCollapse(_ width: Double?, to range: ClosedRange<Double>) -> Double {
        guard let width, width > 0 else {
            return 0
        }
        return clamp(width, to: range)
    }

    private static func clamp(_ width: Double?, to range: ClosedRange<Double>) -> Double {
        let padded = (width ?? 0) + textPadding
        return min(max(padded, range.lowerBound), range.upperBound)
    }
}
