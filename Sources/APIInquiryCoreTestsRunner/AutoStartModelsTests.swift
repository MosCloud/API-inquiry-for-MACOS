import APIInquiryCore
import Foundation

enum AutoStartModelsTests {
    static func run(using harness: TestHarness) {
        testEnabledDisplayIsHighlighted(using: harness)
        testDisabledDisplayIsNeutral(using: harness)
        testRequiresApprovalDisplayIsNotHighlighted(using: harness)
    }

    private static func testEnabledDisplayIsHighlighted(using harness: TestHarness) {
        let display = AutoStartStatus.enabled.controlDisplay

        harness.expectEqual(display.title, "AutoStart", "enabled auto start title")
        harness.expectEqual(display.systemImageName, "bolt.circle.fill", "enabled auto start image")
        harness.expectTrue(display.isHighlighted, "enabled auto start highlighted")
    }

    private static func testDisabledDisplayIsNeutral(using harness: TestHarness) {
        let display = AutoStartStatus.disabled.controlDisplay

        harness.expectEqual(display.title, "AutoStart", "disabled auto start title")
        harness.expectEqual(display.systemImageName, "bolt.circle", "disabled auto start image")
        harness.expectTrue(!display.isHighlighted, "disabled auto start not highlighted")
    }

    private static func testRequiresApprovalDisplayIsNotHighlighted(using harness: TestHarness) {
        let display = AutoStartStatus.requiresApproval.controlDisplay

        harness.expectEqual(display.systemImageName, "exclamationmark.circle", "requires approval auto start image")
        harness.expectTrue(!display.isHighlighted, "requires approval auto start not highlighted")
    }
}
