import APIInquiryCore
import Foundation

enum SecondaryRowColumnsTests {
    static func run(using harness: TestHarness) {
        testCompactWhenEverythingIsShort(using: harness)
        testWidensForAMoneyValue(using: harness)
        testClampsAtBothEnds(using: harness)
    }

    /// A panel with only percentages should stay tight, not reserve room for money.
    private static func testCompactWhenEverythingIsShort(using harness: TestHarness) {
        let widths = SecondaryRowColumnWidths.fit(
            label: [26],
            value: [26, 24],
            trailing: [28, 30]
        )
        harness.expectEqual(widths.label, 32, "short labels compact to their own width")
        harness.expectEqual(widths.value, 32, "percentage column fits the widest percentage")
        harness.expectEqual(widths.trailing, 36, "trailing column follows the widest date")
    }

    /// Mixing a balance row and a quota row widens the shared value column, so they align.
    private static func testWidensForAMoneyValue(using harness: TestHarness) {
        let widths = SecondaryRowColumnWidths.fit(
            label: [26, 34],
            value: [26, 46],
            trailing: [28, 24]
        )
        harness.expectEqual(widths.label, 40, "label column fits the widest label")
        harness.expectEqual(widths.value, 52, "value column grows for the money amount")
        harness.expectEqual(widths.trailing, 34, "trailing column is unaffected by the value")
    }

    private static func testClampsAtBothEnds(using harness: TestHarness) {
        let narrow = SecondaryRowColumnWidths.fit(label: [0], value: [0], trailing: [0])
        harness.expectEqual(narrow.label, 24, "label never collapses below the floor")
        harness.expectEqual(narrow.value, 26, "value never collapses below the floor")
        harness.expectEqual(narrow.trailing, 24, "trailing never collapses below the floor")

        let wide = SecondaryRowColumnWidths.fit(label: [120], value: [400], trailing: [120])
        harness.expectEqual(wide.label, 46, "label stops at the ceiling")
        harness.expectEqual(wide.value, 72, "value stops at the ceiling")
        harness.expectEqual(wide.trailing, 44, "trailing stops at the ceiling")
    }
}
