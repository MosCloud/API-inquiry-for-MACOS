import APIInquiryCore
import Foundation

enum CodexCredentialStoreTests {
    static func run(using harness: TestHarness) {
        testConfigurationURLForwardsProvidersItDoesNotOwn(using: harness)
        testDecoratorOrderDoesNotHideConfigurationURLs(using: harness)
        testCodexAuthFileTakesPrecedenceOverFallback(using: harness)
        testMissingCodexAuthFileFallsBackToDelegate(using: harness)
        testCodexAuthFileStatusReportsMalformedFile(using: harness)
        testCodexAuthFileStatusReportsMissingAccessToken(using: harness)
        testCodexAuthFileStatusReportsUsableFile(using: harness)
        testDeletingCodexCredentialDoesNotDeleteAuthFile(using: harness)
        testCodexConfigTargetOpensExistingAuthFile(using: harness)
        testCodexConfigTargetFallsBackToConfigDirectory(using: harness)
        testCodexConfigTargetDoesNotCreateMissingConfigDirectory(using: harness)
        testCodexConfigTargetForOpeningCreatesMissingConfigDirectory(using: harness)
    }

    private static func testCodexAuthFileTakesPrecedenceOverFallback(using harness: TestHarness) {
        let authJSON = #"{"tokens":{"access_token":"test-access-token","account_id":"test-account"}}"#
        let authFileURL = writeTemporaryAuthFile(authJSON)
        let fallback = RecordingCredentialStore(credentialsByAccount: ["codex-session-token": "fallback-token"])
        let store = CodexCredentialStore(delegate: fallback, authFileURLs: [authFileURL])

        harness.expectEqual(
            try? store.credential(forAccount: "codex-session-token"),
            authJSON,
            "codex auth file credential takes precedence"
        )
        harness.expectEqual(fallback.requestedAccounts, [], "codex auth file avoids fallback read")

        removeTemporaryFile(authFileURL)
    }

    private static func testMissingCodexAuthFileFallsBackToDelegate(using harness: TestHarness) {
        let missingURL = temporaryAuthFileURL()
        let fallback = RecordingCredentialStore(credentialsByAccount: ["codex-session-token": "fallback-token"])
        let store = CodexCredentialStore(delegate: fallback, authFileURLs: [missingURL])

        harness.expectEqual(
            try? store.credential(forAccount: "codex-session-token"),
            "fallback-token",
            "codex missing auth file falls back to delegate"
        )
        harness.expectEqual(fallback.requestedAccounts, ["codex-session-token"], "codex missing auth file reads fallback")
    }

    private static func testCodexAuthFileStatusReportsMalformedFile(using harness: TestHarness) {
        let authFileURL = writeTemporaryAuthFile("{")
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [authFileURL])

        harness.expectEqual(
            store.codexAuthFileStatus(),
            .malformed(authFileURL),
            "codex auth file status reports malformed file"
        )

        removeTemporaryFile(authFileURL)
    }

    private static func testCodexAuthFileStatusReportsMissingAccessToken(using harness: TestHarness) {
        let authFileURL = writeTemporaryAuthFile(#"{"tokens":{}}"#)
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [authFileURL])

        harness.expectEqual(
            store.codexAuthFileStatus(),
            .missingAccessToken(authFileURL),
            "codex auth file status reports missing access token"
        )

        removeTemporaryFile(authFileURL)
    }

    private static func testCodexAuthFileStatusReportsUsableFile(using harness: TestHarness) {
        let authFileURL = writeTemporaryAuthFile(#"{"tokens":{"access_token":"test-access-token"}}"#)
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [authFileURL])

        harness.expectEqual(
            store.codexAuthFileStatus(),
            .usable(authFileURL),
            "codex auth file status reports usable file"
        )

        removeTemporaryFile(authFileURL)
    }

    private static func testDeletingCodexCredentialDoesNotDeleteAuthFile(using harness: TestHarness) {
        let authJSON = #"{"tokens":{"access_token":"test-access-token"}}"#
        let authFileURL = writeTemporaryAuthFile(authJSON)
        let fallback = RecordingCredentialStore(credentialsByAccount: ["codex-session-token": "fallback-token"])
        let store = CodexCredentialStore(delegate: fallback, authFileURLs: [authFileURL])

        try? store.deleteCredential(forAccount: "codex-session-token")

        harness.expectTrue(
            FileManager.default.fileExists(atPath: authFileURL.path),
            "codex delete keeps auth file"
        )
        harness.expectEqual(
            try? fallback.credential(forAccount: "codex-session-token"),
            nil,
            "codex delete removes fallback credential"
        )

        removeTemporaryFile(authFileURL)
    }

    private static func testCodexConfigTargetOpensExistingAuthFile(using harness: TestHarness) {
        let authJSON = #"{"tokens":{"access_token":"test-access-token"}}"#
        let authFileURL = writeTemporaryAuthFile(authJSON)
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [authFileURL])

        harness.expectEqual(
            store.codexConfigTargetURL(),
            authFileURL,
            "codex config target opens existing auth file"
        )

        removeTemporaryFile(authFileURL)
    }

    private static func testCodexConfigTargetFallsBackToConfigDirectory(using harness: TestHarness) {
        let missingURL = temporaryAuthFileURL()
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [missingURL])

        harness.expectEqual(
            store.codexConfigTargetURL(),
            missingURL.deletingLastPathComponent(),
            "codex config target falls back to config directory"
        )
    }

    private static func testCodexConfigTargetDoesNotCreateMissingConfigDirectory(using harness: TestHarness) {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "api-inquiry-codex-config-\(UUID().uuidString)")
        let missingURL = missingDirectory.appending(path: "auth.json")
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [missingURL])

        harness.expectEqual(
            store.codexConfigTargetURL(),
            nil,
            "codex config target does not create missing config directory"
        )
        harness.expectTrue(
            FileManager.default.fileExists(atPath: missingDirectory.path) == false,
            "codex config target keeps missing directory absent"
        )
    }

    private static func testCodexConfigTargetForOpeningCreatesMissingConfigDirectory(using harness: TestHarness) {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "api-inquiry-codex-config-\(UUID().uuidString)")
        let missingURL = missingDirectory.appending(path: "auth.json")
        let store = CodexCredentialStore(delegate: RecordingCredentialStore(credentialsByAccount: [:]), authFileURLs: [missingURL])

        harness.expectEqual(
            store.codexConfigTargetURLCreatingDirectoryIfNeeded(),
            URL(fileURLWithPath: missingDirectory.path),
            "codex config target for opening returns created config directory"
        )
        harness.expectTrue(
            FileManager.default.fileExists(atPath: missingDirectory.path),
            "codex config target for opening creates missing config directory"
        )

        removeTemporaryFile(missingDirectory)
    }

    private static func temporaryAuthFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "api-inquiry-codex-auth-\(UUID().uuidString).json")
    }

    private static func writeTemporaryAuthFile(_ contents: String) -> URL {
        let url = temporaryAuthFileURL()
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func removeTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// A decorator must forward providers it does not own; answering nil would hide the
    /// 打开配置 entry of anything sitting above it in the chain (#83).
    private static func testConfigurationURLForwardsProvidersItDoesNotOwn(using harness: TestHarness) {
        let stubURL = URL(fileURLWithPath: "/tmp/stub-provider-config.json")
        let store = CodexCredentialStore(
            delegate: ConfigurationURLStubStore(url: stubURL),
            authFileURLs: [URL(fileURLWithPath: "/tmp/does-not-exist-auth.json")]
        )

        harness.expectEqual(
            store.configurationURL(for: .deepseek),
            stubURL,
            "codex store forwards providers it does not own"
        )
        harness.expectTrue(
            store.configurationURL(for: .codex) != stubURL,
            "codex store answers for codex itself instead of forwarding"
        )
    }

    /// The chain the app builds must resolve every provider, whatever the order of the
    /// decorators: a config entry cannot be swallowed by a layer above it.
    private static func testDecoratorOrderDoesNotHideConfigurationURLs(using harness: TestHarness) {
        let stubURL = URL(fileURLWithPath: "/tmp/stub-provider-config.json")
        let stub = ConfigurationURLStubStore(url: stubURL)

        let openCodeOutside = OpenCodeCredentialStore(
            delegate: CodexCredentialStore(delegate: stub, authFileURLs: [URL(fileURLWithPath: "/tmp/does-not-exist-auth.json")]),
            openCodeAccount: "opencode-api-key",
            databaseURL: URL(fileURLWithPath: "/tmp/does-not-exist-opencode.db"),
            configDirectoryURL: URL(fileURLWithPath: "/tmp/does-not-exist-opencode")
        )
        harness.expectEqual(
            openCodeOutside.configurationURL(for: .zhipuCodingPlan),
            stubURL,
            "a provider nobody owns still reaches the delegate through both layers"
        )

        let codexOutside = CodexCredentialStore(
            delegate: OpenCodeCredentialStore(
                delegate: stub,
                openCodeAccount: "opencode-api-key",
                databaseURL: URL(fileURLWithPath: "/tmp/does-not-exist-opencode.db"),
                configDirectoryURL: URL(fileURLWithPath: "/tmp/does-not-exist-opencode")
            ),
            authFileURLs: [URL(fileURLWithPath: "/tmp/does-not-exist-auth.json")]
        )
        harness.expectEqual(
            codexOutside.configurationURL(for: .zhipuCodingPlan),
            stubURL,
            "the same answer holds with the decorators in the opposite order"
        )
    }
}

/// Answers `configurationURL` for every provider, unlike the real Keychain store.
private final class ConfigurationURLStubStore: CredentialStore, LocalConfigurationProviding {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func credential(forAccount account: String) throws -> String? { nil }
    func saveCredential(_ credential: String, forAccount account: String) throws {}
    func deleteCredential(forAccount account: String) throws {}
    func configurationURL(for providerID: ProviderID) -> URL? { url }
}

private final class RecordingCredentialStore: CredentialStore {
    private var credentialsByAccount: [String: String]
    private(set) var requestedAccounts: [String] = []

    init(credentialsByAccount: [String: String]) {
        self.credentialsByAccount = credentialsByAccount
    }

    func credential(forAccount account: String) throws -> String? {
        requestedAccounts.append(account)
        return credentialsByAccount[account]
    }

    func saveCredential(_ credential: String, forAccount account: String) throws {
        credentialsByAccount[account] = credential
    }

    func deleteCredential(forAccount account: String) throws {
        credentialsByAccount.removeValue(forKey: account)
    }
}
