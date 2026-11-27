import APIInquiryCore
import Foundation

/// S4b: the decorator that puts a live local session into the credential slot.
///
/// Without this layer the refresh controller sees an empty credential, answers "not
/// configured", and never calls the provider — so these tests guard the one wiring decision
/// that decides whether the feature works at all.
enum AntigravityCredentialStoreTests {
    static func run(using harness: TestHarness) {
        testForwardsProvidersItDoesNotOwn(using: harness)
        testMintsSessionForItsOwnAccount(using: harness)
        testReturnsNilWhenAntigravityIsNotRunning(using: harness)
        testNeverWritesToTheDelegateForItsOwnAccount(using: harness)
        testConfigurationURLForwardsOtherProviders(using: harness)
    }

    private static func testForwardsProvidersItDoesNotOwn(using harness: TestHarness) {
        let delegate = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "delegate-key"])
        let store = AntigravityCredentialStore(
            delegate: delegate,
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        harness.expectEqual(
            try? store.credential(forAccount: "deepseek-api-key"),
            "delegate-key",
            "antigravity store forwards a provider it does not own"
        )
    }

    private static func testMintsSessionForItsOwnAccount(using harness: TestHarness) {
        let directory = makeDirectory()
        defer { removeDirectory(directory) }
        writeDaemonFile(into: directory, httpPort: 63422, pid: 4242, token: fakeToken)

        let store = AntigravityCredentialStore(
            delegate: InMemoryCredentialStore(),
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: directory) { _ in true }
        )

        let credential = try? store.credential(forAccount: "antigravity-local-session")
        harness.expectTrue(credential?.isEmpty == false, "antigravity store produces a non-empty credential")

        let session = credential.flatMap { try? AntigravitySessionPayload.decode($0) }
        harness.expectEqual(session?.httpPort, 63422, "antigravity credential carries the live port")
        harness.expectEqual(session?.csrfToken, fakeToken, "antigravity credential carries the live token")
    }

    private static func testReturnsNilWhenAntigravityIsNotRunning(using harness: TestHarness) {
        let store = AntigravityCredentialStore(
            delegate: InMemoryCredentialStore(),
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        harness.expectEqual(
            try? store.credential(forAccount: "antigravity-local-session"),
            nil,
            "antigravity store reports nothing to read when the app is not running"
        )
    }

    /// The credential belongs to Antigravity's own login; this app must never take it over.
    private static func testNeverWritesToTheDelegateForItsOwnAccount(using harness: TestHarness) {
        let delegate = InMemoryCredentialStore()
        let store = AntigravityCredentialStore(
            delegate: delegate,
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        try? store.saveCredential("someone-elses-value", forAccount: "antigravity-local-session")

        harness.expectEqual(
            try? store.credential(forAccount: "antigravity-local-session"),
            nil,
            "antigravity store ignores a saved value and keeps reading the live session"
        )
    }

    private static func testConfigurationURLForwardsOtherProviders(using harness: TestHarness) {
        let delegate = ForwardingConfigurationStub(url: URL(fileURLWithPath: "/tmp/somewhere"))
        let store = AntigravityCredentialStore(
            delegate: delegate,
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        harness.expectEqual(
            store.configurationURL(for: .codex)?.path,
            "/tmp/somewhere",
            "antigravity store forwards another provider's configuration URL"
        )
    }
}

private let fakeToken = "fake-token-00000000-0000-0000-000000"

private func emptyDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "antigravity-credential-tests-empty")
}

private func makeDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "antigravity-credential-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func writeDaemonFile(into directory: URL, httpPort: Int, pid: Int, token: String) {
    let contents = """
    {"pid":\(pid),"httpsPort":\(httpPort - 1),"httpPort":\(httpPort),"lsVersion":"2.35.2","csrfToken":"\(token)"}
    """
    try? Data(contents.utf8).write(to: directory.appending(path: "hub_\(httpPort).json"))
}

private final class ForwardingConfigurationStub: CredentialStore, LocalConfigurationProviding {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func credential(forAccount account: String) throws -> String? { nil }
    func saveCredential(_ credential: String, forAccount account: String) throws {}
    func deleteCredential(forAccount account: String) throws {}
    func configurationURL(for providerID: ProviderID) -> URL? { url }
}
