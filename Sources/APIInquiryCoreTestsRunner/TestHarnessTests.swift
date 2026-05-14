import Foundation

enum TestHarnessTests {
    static func run(using harness: TestHarness) {
        testEmptyHarnessFails(using: harness)
    }

    private static func testEmptyHarnessFails(using harness: TestHarness) {
        let emptyHarness = TestHarness()

        harness.expectEqual(
            emptyHarness.result,
            .failed(expectationCount: 0, failures: ["No expectations were run."]),
            "empty harness result"
        )
    }
}
