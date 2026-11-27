import APIInquiryCore
import Foundation

/// S1: reads the Antigravity daemon file and turns it into the payload a provider receives.
///
/// Fixtures use a fake port and a fake token throughout: the real `hub_*.json` carries a live
/// CSRF token, and the project forbids that value reaching tests, logs or fixtures.
enum AntigravityLocalSessionTests {
    static func run(using harness: TestHarness) {
        testReadsDaemonFile(using: harness)
        testMissingFieldIsUnreadable(using: harness)
        testEmptyDirectoryIsAppNotRunning(using: harness)
        testStaleFileWithDeadProcessIsAppNotRunning(using: harness)
        testNewestLiveFileWins(using: harness)
        testPayloadRoundTrip(using: harness)
        testPayloadRejectsGarbage(using: harness)
    }

    private static func testReadsDaemonFile(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        writeDaemonFile(
            into: directory,
            name: "hub_63422.json",
            httpPort: 63422,
            pid: 4242,
            token: fakeToken
        )

        let reader = AntigravitySessionReader(daemonDirectoryURL: directory) { _ in true }
        let session = try? reader.readSession()

        harness.expectEqual(session?.httpPort, 63422, "antigravity reads httpPort from the daemon file")
        harness.expectEqual(session?.pid, 4242, "antigravity reads pid from the daemon file")
        harness.expectEqual(session?.csrfToken, fakeToken, "antigravity reads csrfToken from the daemon file")
        harness.expectEqual(
            session?.csrfToken.count,
            36,
            "antigravity fixture token has the length the real one has"
        )
        harness.expectEqual(
            session?.baseURL?.absoluteString,
            "http://127.0.0.1:63422",
            "antigravity builds the plaintext base URL"
        )
    }

    private static func testMissingFieldIsUnreadable(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        // No csrfToken: the one field the reader cannot work without.
        writeRawFile(
            into: directory,
            name: "hub_63422.json",
            contents: #"{"pid":4242,"httpsPort":63421,"httpPort":63422,"lsVersion":"2.35.2"}"#
        )

        let reader = AntigravitySessionReader(daemonDirectoryURL: directory) { _ in true }

        do {
            _ = try reader.readSession()
            harness.expectTrue(false, "antigravity missing csrfToken should throw unreadable")
        } catch let error as AntigravitySessionError {
            harness.expectEqual(error, .unreadable, "antigravity missing csrfToken is unreadable")
        } catch {
            harness.expectTrue(false, "antigravity missing csrfToken threw an unexpected error: \(error)")
        }
    }

    private static func testEmptyDirectoryIsAppNotRunning(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }

        let reader = AntigravitySessionReader(daemonDirectoryURL: directory) { _ in true }

        do {
            _ = try reader.readSession()
            harness.expectTrue(false, "antigravity empty daemon directory should throw appNotRunning")
        } catch let error as AntigravitySessionError {
            harness.expectEqual(error, .appNotRunning, "antigravity empty daemon directory is appNotRunning")
        } catch {
            harness.expectTrue(false, "antigravity empty daemon directory threw an unexpected error: \(error)")
        }
    }

    /// The crash case: the file survived but the process did not, so the app is not running.
    private static func testStaleFileWithDeadProcessIsAppNotRunning(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        writeDaemonFile(
            into: directory,
            name: "hub_63422.json",
            httpPort: 63422,
            pid: 4242,
            token: fakeToken
        )

        let reader = AntigravitySessionReader(daemonDirectoryURL: directory) { _ in false }

        do {
            _ = try reader.readSession()
            harness.expectTrue(false, "antigravity stale file with dead pid should throw appNotRunning")
        } catch let error as AntigravitySessionError {
            harness.expectEqual(error, .appNotRunning, "antigravity dead pid is appNotRunning")
        } catch {
            harness.expectTrue(false, "antigravity dead pid threw an unexpected error: \(error)")
        }
    }

    /// Two products running at once: the newer file is the one that just started.
    private static func testNewestLiveFileWins(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let older = writeDaemonFile(
            into: directory,
            name: "hub_53870.json",
            httpPort: 53870,
            pid: 1111,
            token: fakeToken
        )
        let newer = writeDaemonFile(
            into: directory,
            name: "hub_63422.json",
            httpPort: 63422,
            pid: 2222,
            token: fakeToken
        )
        setModificationDate(older, to: Date(timeIntervalSince1970: 1_000_000))
        setModificationDate(newer, to: Date(timeIntervalSince1970: 2_000_000))

        let reader = AntigravitySessionReader(daemonDirectoryURL: directory) { _ in true }
        let session = try? reader.readSession()

        harness.expectEqual(session?.httpPort, 63422, "antigravity prefers the newest live daemon file")
    }

    private static func testPayloadRoundTrip(using harness: TestHarness) {
        let session = AntigravityLocalSession(httpPort: 63422, pid: 4242, csrfToken: fakeToken)
        let encoded = AntigravitySessionPayload.encode(session)
        let decoded = try? AntigravitySessionPayload.decode(encoded)

        harness.expectEqual(decoded, session, "antigravity session payload round-trips")
        harness.expectTrue(!encoded.isEmpty, "antigravity session payload is non-empty for the refresh chain")
    }

    private static func testPayloadRejectsGarbage(using harness: TestHarness) {
        harness.expectTrue(
            sessionError(from: "") == .unreadable,
            "antigravity empty payload is unreadable"
        )
        harness.expectTrue(
            sessionError(from: "not-a-session") == .unreadable,
            "antigravity malformed payload is unreadable"
        )
    }

    /// The harness has no generic "throws this error" helper, and one test does not justify
    /// adding one; capturing the case keeps the assertion just as specific.
    private static func sessionError(from payload: String) -> AntigravitySessionError? {
        do {
            _ = try AntigravitySessionPayload.decode(payload)
            return nil
        } catch let error as AntigravitySessionError {
            return error
        } catch {
            return nil
        }
    }
}

/// A 36-character stand-in for the real token, which is the same length by observation and
/// must never appear in a fixture.
private let fakeToken = "fake-token-00000000-0000-0000-000000"

private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "antigravity-session-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

@discardableResult
private func writeDaemonFile(
    into directory: URL,
    name: String,
    httpPort: Int,
    pid: Int,
    token: String
) -> URL {
    let contents = """
    {"pid":\(pid),"httpsPort":\(httpPort - 1),"httpPort":\(httpPort),"lsVersion":"2.35.2","csrfToken":"\(token)"}
    """
    return writeRawFile(into: directory, name: name, contents: contents)
}

@discardableResult
private func writeRawFile(into directory: URL, name: String, contents: String) -> URL {
    let url = directory.appending(path: name)
    try? Data(contents.utf8).write(to: url)
    return url
}

private func setModificationDate(_ url: URL, to date: Date) {
    try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}
