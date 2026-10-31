import APIInquiryCore
import Foundation
import SQLite3

enum OpenCodeCredentialStoreTests {
    static func run(using harness: TestHarness) {
        configurationTests(using: harness)
        testReadsKeyFromDatabase(using: harness)
        testFallsBackToDelegateWhenDatabaseIsMissing(using: harness)
        testFallsBackToDelegateWhenCredentialRowIsMissing(using: harness)
        testFallsBackToDelegateWhenValueIsMalformed(using: harness)
        testFallsBackToDelegateWhenTableIsMissing(using: harness)
        testReadsCredentialWithCurrentIntegrationID(using: harness)
        testParsesOAuthAccessToken(using: harness)
        testCredentialStatusReportsDatabaseState(using: harness)
        testForwardsCodexIntrospection(using: harness)
        testOtherAccountsDelegateToTheWrappedStore(using: harness)
    }

    private static func testReadsKeyFromDatabase(using harness: TestHarness) {
        let fixture = makeFixture(value: #"{"type":"key","key":"opencode-stored-key"}"#)
        defer { fixture.cleanup() }

        let store = OpenCodeCredentialStore(delegate: InMemoryCredentialStore(), databaseURL: fixture.databaseURL)
        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "opencode-stored-key",
            "opencode credential store reads the key from the CLI database"
        )
        harness.expectEqual(store.credentialStatus(), .usable, "opencode credential status is usable")
    }

    private static func testFallsBackToDelegateWhenDatabaseIsMissing(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let delegate = InMemoryCredentialStore(credentialsByAccount: [
            OpenCodeCredentialStore.defaultOpenCodeAccount: "manual-key"
        ])
        let store = OpenCodeCredentialStore(
            delegate: delegate,
            databaseURL: directory.appendingPathComponent("missing.db")
        )

        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "manual-key",
            "missing opencode database falls back to the keychain delegate"
        )
        harness.expectEqual(store.credentialStatus(), .missingDatabase, "missing database status")
    }

    private static func testFallsBackToDelegateWhenCredentialRowIsMissing(using harness: TestHarness) {
        let fixture = makeFixture(value: nil)
        defer { fixture.cleanup() }

        let delegate = InMemoryCredentialStore(credentialsByAccount: [
            OpenCodeCredentialStore.defaultOpenCodeAccount: "manual-key"
        ])
        let store = OpenCodeCredentialStore(delegate: delegate, databaseURL: fixture.databaseURL)

        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "manual-key",
            "empty credential table falls back to the delegate"
        )
        harness.expectEqual(store.credentialStatus(), .missingCredential, "empty credential table status")
    }

    private static func testFallsBackToDelegateWhenValueIsMalformed(using harness: TestHarness) {
        let fixture = makeFixture(value: "not-json")
        defer { fixture.cleanup() }

        let delegate = InMemoryCredentialStore(credentialsByAccount: [
            OpenCodeCredentialStore.defaultOpenCodeAccount: "manual-key"
        ])
        let store = OpenCodeCredentialStore(delegate: delegate, databaseURL: fixture.databaseURL)

        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "manual-key",
            "malformed credential value falls back to the delegate"
        )
        harness.expectEqual(store.credentialStatus(), .malformedCredential, "malformed credential status")
    }

    private static func testFallsBackToDelegateWhenTableIsMissing(using harness: TestHarness) {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("empty.db")
        var connection: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &connection) == SQLITE_OK else {
            harness.expectTrue(false, "could not create empty sqlite database")
            return
        }
        sqlite3_exec(connection, "CREATE TABLE unrelated (id TEXT);", nil, nil, nil)
        sqlite3_close(connection)

        let delegate = InMemoryCredentialStore(credentialsByAccount: [
            OpenCodeCredentialStore.defaultOpenCodeAccount: "manual-key"
        ])
        let store = OpenCodeCredentialStore(delegate: delegate, databaseURL: databaseURL)

        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "manual-key",
            "database without a credential table falls back to the delegate"
        )
        harness.expectEqual(store.credentialStatus(), .missingCredential, "schema drift reports missing credential")
    }

    private static func testReadsCredentialWithCurrentIntegrationID(using harness: TestHarness) {
        let fixture = makeFixture(
            value: #"{"type":"key","key":"opencode-go-key"}"#,
            integrationID: "opencode-go",
            label: "OpenCode Go"
        )
        defer { fixture.cleanup() }

        let store = OpenCodeCredentialStore(delegate: InMemoryCredentialStore(), databaseURL: fixture.databaseURL)
        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "opencode-go-key",
            "current opencode-go integration id is read"
        )
    }

    private static func testParsesOAuthAccessToken(using harness: TestHarness) {
        let fixture = makeFixture(value: #"{"type":"oauth","access":"oauth-access-token"}"#)
        defer { fixture.cleanup() }

        let store = OpenCodeCredentialStore(delegate: InMemoryCredentialStore(), databaseURL: fixture.databaseURL)
        harness.expectEqual(
            try? store.credential(forAccount: OpenCodeCredentialStore.defaultOpenCodeAccount),
            "oauth-access-token",
            "opencode oauth records expose their access token"
        )
    }

    private static func testCredentialStatusReportsDatabaseState(using harness: TestHarness) {
        let fixture = makeFixture(value: #"{"type":"key","key":"opencode-stored-key"}"#)
        defer { fixture.cleanup() }

        harness.expectEqual(
            OpenCodeCredentialStore.parseCredentialValue(#"{"type":"key","key":"abc"}"#),
            "abc",
            "direct credential parsing"
        )
        harness.expectEqual(
            OpenCodeCredentialStore.parseCredentialValue(#"{"type":"key","key":"   "}"#),
            nil,
            "blank keys are rejected"
        )
        harness.expectEqual(
            OpenCodeCredentialStore.parseCredentialValue("[]"),
            nil,
            "non-object payloads are rejected"
        )
        let store = OpenCodeCredentialStore(delegate: InMemoryCredentialStore(), databaseURL: fixture.databaseURL)
        harness.expectEqual(store.credentialStatus(), .usable, "database fixture is usable")
    }

    private static func testForwardsCodexIntrospection(using harness: TestHarness) {
        let fixture = makeFixture(value: #"{"type":"key","key":"opencode-key"}"#)
        defer { fixture.cleanup() }

        let codexStore = CodexCredentialStore(
            delegate: InMemoryCredentialStore(),
            authFileURLs: []
        )
        let store = OpenCodeCredentialStore(delegate: codexStore, databaseURL: fixture.databaseURL)

        harness.expectEqual(
            store.codexAuthFileStatus(),
            codexStore.codexAuthFileStatus(),
            "opencode store forwards the codex auth file status"
        )
        harness.expectEqual(
            store.codexConfigTargetURL(),
            codexStore.codexConfigTargetURL(),
            "opencode store forwards the codex config target"
        )

        let detached = OpenCodeCredentialStore(delegate: InMemoryCredentialStore(), databaseURL: fixture.databaseURL)
        harness.expectEqual(detached.codexAuthFileStatus(), .missing, "store without codex delegate reports missing auth file")
        harness.expectEqual(detached.codexConfigTargetURL(), nil, "store without codex delegate has no config target")
    }

    private static func testOtherAccountsDelegateToTheWrappedStore(using harness: TestHarness) {
        let delegate = InMemoryCredentialStore(credentialsByAccount: ["deepseek-api-key": "deepseek-key"])
        let store = OpenCodeCredentialStore(delegate: delegate, databaseURL: URL(fileURLWithPath: "/nonexistent"))

        harness.expectEqual(
            try? store.credential(forAccount: "deepseek-api-key"),
            "deepseek-key",
            "other accounts pass through to the wrapped store"
        )
    }

    // MARK: - Fixtures

    private struct DatabaseFixture {
        let directory: URL
        let databaseURL: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencode-credential-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeFixture(
        value: String?,
        integrationID: String = "opencode",
        label: String = "OpenCode Console"
    ) -> DatabaseFixture {
        let directory = makeTemporaryDirectory()
        let databaseURL = directory.appendingPathComponent("opencode.db")

        var connection: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &connection) == SQLITE_OK else {
            return DatabaseFixture(directory: directory, databaseURL: databaseURL)
        }
        defer { sqlite3_close(connection) }

        let schema = """
        CREATE TABLE credential (
            id TEXT PRIMARY KEY,
            integration_id TEXT,
            label TEXT NOT NULL,
            value TEXT NOT NULL,
            connector_id TEXT,
            method_id TEXT,
            active INTEGER,
            time_created INTEGER NOT NULL,
            time_updated INTEGER NOT NULL
        );
        CREATE TABLE unrelated (id TEXT);
        """
        sqlite3_exec(connection, schema, nil, nil, nil)

        guard let value else {
            return DatabaseFixture(directory: directory, databaseURL: databaseURL)
        }

        let insert = """
        INSERT INTO credential (id, integration_id, label, value, active, time_created, time_updated)
        VALUES ('cred_1', '\(integrationID)', '\(label)', '\(value.replacingOccurrences(of: "'", with: "''"))', 1, 0, 0);
        """
        sqlite3_exec(connection, insert, nil, nil, nil)
        return DatabaseFixture(directory: directory, databaseURL: databaseURL)
    }
}

// MARK: - Configuration entry point (Console → API → 打开配置)

extension OpenCodeCredentialStoreTests {
    static func configurationTests(using harness: TestHarness) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencode-config-\(UUID().uuidString)", isDirectory: true)

        let store = OpenCodeCredentialStore(
            delegate: InMemoryCredentialStore(),
            configDirectoryURL: directory
        )

        harness.expectEqual(
            store.configurationURL(for: .opencode),
            nil,
            "missing config directory yields no configuration target"
        )

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        harness.expectEqual(
            store.configurationURL(for: .opencode),
            directory,
            "existing directory is used when no config file exists"
        )

        let jsonc = directory.appendingPathComponent("opencode.jsonc")
        FileManager.default.createFile(atPath: jsonc.path, contents: Data("{}".utf8))
        harness.expectEqual(
            store.configurationURL(for: .opencode),
            jsonc,
            "opencode.jsonc is preferred when present"
        )

        try? FileManager.default.removeItem(at: jsonc)
        let json = directory.appendingPathComponent("opencode.json")
        FileManager.default.createFile(atPath: json.path, contents: Data("{}".utf8))
        harness.expectEqual(
            store.configurationURL(for: .opencode),
            json,
            "opencode.json is the fallback config file"
        )

        harness.expectEqual(
            store.configurationURL(for: .deepseek),
            nil,
            "keychain-backed providers have no local configuration"
        )

        try? FileManager.default.removeItem(at: json)
        try? FileManager.default.removeItem(at: directory)
        harness.expectEqual(
            store.configurationURL(for: .opencode),
            nil,
            "removed directory yields no configuration target"
        )
    }
}
