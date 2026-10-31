import Foundation

enum TestHarnessTests {
    static func run(using harness: TestHarness) async {
        testEmptyHarnessFails(using: harness)
        await testExhaustedWaitBoundedPollReturnsFalse(using: harness)
        await testSatisfiedWaitBoundedPollReturnsTrue(using: harness)
    }

    private static func testEmptyHarnessFails(using harness: TestHarness) {
        let emptyHarness = TestHarness()

        harness.expectEqual(
            emptyHarness.result,
            .failed(expectationCount: 0, failures: ["No expectations were run."]),
            "empty harness result"
        )
    }

    /// #70: a waiter that times out must tell the caller so, instead of printing a
    /// warning to stderr and letting the following assertions pass on a state the test
    /// never actually reached.
    private static func testExhaustedWaitBoundedPollReturnsFalse(using harness: TestHarness) async {
        var attempts = 0

        let satisfied = await waitUntilBounded(attempts: 3, interval: 0) {
            attempts += 1
            return false
        }

        harness.expectEqual(satisfied, false, "an exhausted bounded wait reports false")
        harness.expectEqual(attempts, 3, "an exhausted bounded wait spends every attempt")
    }

    private static func testSatisfiedWaitBoundedPollReturnsTrue(using harness: TestHarness) async {
        var attempts = 0

        let satisfied = await waitUntilBounded(attempts: 100, interval: 0) {
            attempts += 1
            return attempts == 3
        }

        harness.expectEqual(satisfied, true, "a satisfied bounded wait reports true")
        harness.expectEqual(attempts, 3, "a satisfied bounded wait stops polling immediately")
    }
}
