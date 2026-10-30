import Foundation
import SQLite3

public enum OpenCodeCredentialStatus: Equatable {
    case missingDatabase
    case missingCredential
    case malformedCredential
    case usable
}

/// Reads the OpenCode CLI credential so the Console needs no manual copy/paste.
///
/// The CLI keeps its integrations in `<data>/opencode.db` (`credential` table). On this
/// machine the OpenCode Console integration stores `{"type":"key","key":"..."}` there.
/// The database is only ever opened read-only; when it is missing or the schema no
/// longer matches, the store falls back to the Keychain so a manually pasted key still
/// works.
public final class OpenCodeCredentialStore: CredentialStore {
    public static let defaultOpenCodeAccount = "opencode-api-key"

    private let delegate: CredentialStore
    private let openCodeAccount: String
    private let databaseURL: URL

    public init(
        delegate: CredentialStore,
        openCodeAccount: String = OpenCodeCredentialStore.defaultOpenCodeAccount,
        databaseURL: URL? = nil
    ) {
        self.delegate = delegate
        self.openCodeAccount = openCodeAccount
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
    }

    public static func defaultDatabaseURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("opencode")
            .appendingPathComponent("opencode.db")
    }

    public func credential(forAccount account: String) throws -> String? {
        guard account == openCodeAccount else {
            return try delegate.credential(forAccount: account)
        }

        if let storedKey = readCredentialFromDatabase() {
            return storedKey
        }

        return try delegate.credential(forAccount: account)
    }

    public func saveCredential(_ credential: String, forAccount account: String) throws {
        try delegate.saveCredential(credential, forAccount: account)
    }

    public func deleteCredential(forAccount account: String) throws {
        try delegate.deleteCredential(forAccount: account)
    }

    public func credentialStatus() -> OpenCodeCredentialStatus {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .missingDatabase
        }
        guard let rawValue = queryRawCredentialValue() else {
            return .missingCredential
        }
        return Self.parseCredentialValue(rawValue) == nil ? .malformedCredential : .usable
    }

    /// Parses the stored JSON value. `key` covers API-key integrations, `access` covers
    /// OAuth sessions, which the CLI exposes under the same record.
    public static func parseCredentialValue(_ rawValue: String) -> String? {
        guard let data = rawValue.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        for key in ["key", "access"] {
            if let value = object[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private func readCredentialFromDatabase() -> String? {
        guard let rawValue = queryRawCredentialValue() else {
            return nil
        }
        return Self.parseCredentialValue(rawValue)
    }

    private func queryRawCredentialValue() -> String? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        var connection: OpaquePointer?
        let uri = "file:\(databaseURL.path)?mode=ro"
        guard sqlite3_open_v2(uri, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(connection)
            return nil
        }
        defer { sqlite3_close(connection) }

        // The integration id is not stable across OpenCode releases: the CLI has used
        // both "opencode" and "opencode-go" (labels "OpenCode Console" / "OpenCode Go"),
        // so match the family and prefer the most recently updated active record.
        let sql = """
        SELECT value FROM credential
        WHERE active = 1
          AND (integration_id LIKE 'opencode%' OR label LIKE 'OpenCode%')
        ORDER BY time_updated DESC
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: text)
    }
}
