import Darwin
import Foundation

/// Why the local Antigravity session could not be used.
///
/// These answer "what should the user do", so each case has its own wording rather than
/// collapsing into one "Antigravity unavailable": a closed app and a signed-out app need
/// different actions, and a stale RPC path is nobody's fault but the app's age.
public enum AntigravitySessionError: Error, Equatable, LocalizedError {
    /// No `hub_*.json` in the daemon directory describes a live language server.
    case appNotRunning
    /// The server is up but rejected the request: it is signed out, or the token is stale.
    case notSignedIn
    /// The quota RPC did not answer as expected, which usually means Antigravity changed.
    case versionChanged
    /// The daemon file exists but does not carry the fields this reader needs.
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .appNotRunning:
            return "Antigravity is not running. Open it, sign in, then refresh."
        case .notSignedIn:
            return "Antigravity is running but signed out. Sign in there, then refresh."
        case .versionChanged:
            return "Antigravity's local quota endpoint did not answer as expected. Updating Antigravity may be required."
        case .unreadable:
            return "Antigravity's local session file could not be read."
        }
    }
}

extension AntigravitySessionError {
    public func localizedDescription(strings: LocalizedStrings) -> String {
        switch self {
        case .appNotRunning:
            return strings.antigravityNotRunning
        case .notSignedIn:
            return strings.antigravityNotSignedIn
        case .versionChanged:
            return strings.antigravityVersionChanged
        case .unreadable:
            return strings.antigravitySessionUnreadable
        }
    }
}

/// A live local Antigravity language server, as described by its daemon file.
public struct AntigravityLocalSession: Equatable {
    /// The plaintext HTTP JSON-RPC listener. The TLS listener beside it cannot serve these
    /// calls, so the port matters: they differ (`63421` vs `63422` on the machine this was
    /// measured on).
    public let httpPort: Int
    /// The language server process. Used only to tell a live file from a leftover one.
    public let pid: Int32
    /// The CSRF token the RPC requires. Rotates with the process, so never cache it.
    public let csrfToken: String

    public init(httpPort: Int, pid: Int32, csrfToken: String) {
        self.httpPort = httpPort
        self.pid = pid
        self.csrfToken = csrfToken
    }

    public var baseURL: URL? {
        URL(string: "http://127.0.0.1:\(httpPort)")
    }
}

/// Keeps the token out of logs.
///
/// The payload that reaches `BalanceProvider.fetchSnapshot(apiKey:)` carries this token, and
/// the project forbids logging it. A redacted description removes the easy way to leak it by
/// accident; it cannot stop deliberate printing, which is why the token is also never written
/// to disk anywhere in this feature.
extension AntigravityLocalSession: CustomStringConvertible {
    public var description: String {
        "AntigravityLocalSession(pid: \(pid), httpPort: \(httpPort), csrfToken: <redacted>)"
    }
}

/// The string a credential store hands to `fetchSnapshot(apiKey:)`.
///
/// `BalanceRefreshController` treats an empty credential as "not configured" and never calls
/// the provider, so this provider cannot be key-based and still work. Encoding the session
/// into the credential slot is how a locally-configured provider joins that chain without
/// touching the refresh controller — the same trick `CodexCredentialStore` plays with
/// `~/.codex/auth.json`.
public enum AntigravitySessionPayload {
    private struct Wire: Codable {
        let httpPort: Int
        let csrfToken: String
        let pid: Int32
    }

    public static func encode(_ session: AntigravityLocalSession) -> String {
        let wire = Wire(httpPort: session.httpPort, csrfToken: session.csrfToken, pid: session.pid)
        guard let data = try? JSONEncoder().encode(wire),
              let text = String(data: data, encoding: .utf8) else {
            // Encoding three primitives cannot fail; an empty string is the one value the
            // refresh controller already treats as "not configured".
            return ""
        }
        return text
    }

    public static func decode(_ value: String) throws -> AntigravityLocalSession {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let wire = try? JSONDecoder().decode(Wire.self, from: data),
              !wire.csrfToken.isEmpty else {
            throw AntigravitySessionError.unreadable
        }
        return AntigravityLocalSession(httpPort: wire.httpPort, pid: wire.pid, csrfToken: wire.csrfToken)
    }
}

/// Finds and reads the daemon file the Antigravity language server writes on startup.
///
/// The server binds an ephemeral port and generates a fresh CSRF token, then records both in
/// `~/.gemini/antigravity/daemon/hub_<port>.json` with `0600`. Reading that file is the only
/// way to get the pair without going through OAuth: the token is passed to the process on
/// stdin (`--read_host_bridge_token_from_stdin`), so it is absent from `argv`, and the HTML
/// the server serves carries an empty `csrfToken`.
public struct AntigravitySessionReader {
    private let daemonDirectoryURL: URL
    private let isProcessAlive: (Int32) -> Bool

    public init(
        daemonDirectoryURL: URL = AntigravitySessionReader.defaultDaemonDirectoryURL,
        isProcessAlive: @escaping (Int32) -> Bool = AntigravitySessionReader.processIsAlive
    ) {
        self.daemonDirectoryURL = daemonDirectoryURL
        self.isProcessAlive = isProcessAlive
    }

    public static var defaultDaemonDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".gemini/antigravity/daemon")
    }

    /// `kill(pid, 0)` answers "does this process exist" without sending a signal.
    ///
    /// `EPERM` means it exists but belongs to another user, which is still alive.
    public static func processIsAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else {
            return false
        }
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    /// The newest daemon file whose process is still running.
    ///
    /// A crash can leave the file behind, so the pid check — not the file's existence — decides
    /// whether Antigravity is up. Several files can coexist when more than one product runs;
    /// newest-first is the closest thing to "the one that just started".
    public func readSession() throws -> AntigravityLocalSession {
        let candidates = daemonFiles()
        guard !candidates.isEmpty else {
            throw AntigravitySessionError.appNotRunning
        }

        var decodedAtLeastOne = false
        for fileURL in candidates {
            guard let session = try? decodeDaemonFile(at: fileURL) else {
                continue
            }
            decodedAtLeastOne = true
            if isProcessAlive(session.pid) {
                return session
            }
        }

        // A file that parsed but whose process is gone means Antigravity was closed and left
        // the file behind. A file that did not parse at all is a different answer: the app
        // may well be running, and telling the user to open it would be wrong.
        throw decodedAtLeastOne
            ? AntigravitySessionError.appNotRunning
            : AntigravitySessionError.unreadable
    }

    private func daemonFiles() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: daemonDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { $0.lastPathComponent.hasPrefix("hub_") && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return left > right
            }
    }

    private func decodeDaemonFile(at fileURL: URL) throws -> AntigravityLocalSession {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let httpPort = object["httpPort"] as? Int,
              let pid = object["pid"] as? Int,
              let csrfToken = object["csrfToken"] as? String,
              !csrfToken.isEmpty else {
            throw AntigravitySessionError.unreadable
        }

        return AntigravityLocalSession(httpPort: httpPort, pid: Int32(pid), csrfToken: csrfToken)
    }
}
