import APIInquiryCore
import Foundation

enum CodexCredentialStoreTests {
    static func run(using harness: TestHarness) {
        testCodexAuthFileTakesPrecedenceOverFallback(using: harness)
        testMissingCodexAuthFileFallsBackToDelegate(using: harness)
        testDeletingCodexCredentialDoesNotDeleteAuthFile(using: harness)
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
