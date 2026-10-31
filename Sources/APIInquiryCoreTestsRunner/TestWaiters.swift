import Darwin
import Foundation

/// Polls `condition` up to `attempts` times, sleeping `interval` nanoseconds between
/// attempts, and reports whether it became true.
///
/// Why this exists (#70): the test doubles in this runner park a `CheckedContinuation`
/// until the code under test starts a request. When that signal never arrives the
/// awaiting task used to stay suspended forever, so the whole runner sat in its run
/// loop until it was killed by hand — and a waiter that gave up silently let the
/// following assertions pass on a state the test never reached. Every waiter must now
/// be bounded *and* hand its outcome to `harness.expectTrue`, so a missed signal turns
/// into a red assertion instead of a hang or a false green.
///
/// `@discardableResult` stays off on purpose: ignoring the outcome is the bug.
func waitUntilBounded(
    attempts: Int,
    interval: UInt64,
    condition: () async -> Bool
) async -> Bool {
    precondition(attempts > 0, "a bounded wait needs at least one attempt")

    for attempt in 0..<attempts {
        if await condition() {
            return true
        }
        guard attempt < attempts - 1 else { break }
        if interval > 0 {
            try? await Task.sleep(nanoseconds: interval)
        } else {
            await Task.yield()
        }
    }

    return false
}
