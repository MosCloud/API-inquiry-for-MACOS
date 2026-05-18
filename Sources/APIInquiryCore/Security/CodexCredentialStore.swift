import Foundation

public final class CodexCredentialStore: CredentialStore {
    private let delegate: CredentialStore
    private let codexAccount: String
    private let authFileURLs: [URL]

    public init(
        delegate: CredentialStore,
        codexAccount: String = "codex-session-token",
        authFileURLs: [URL]? = nil
    ) {
        self.delegate = delegate
        self.codexAccount = codexAccount
        self.authFileURLs = authFileURLs ?? CodexCredentialStore.defaultAuthFileURLs()
    }

    public func credential(forAccount account: String) throws -> String? {
        guard account == codexAccount else {
            return try delegate.credential(forAccount: account)
        }

        if let authFileCredential = readFirstUsableAuthFile() {
            return authFileCredential
        }

        return try delegate.credential(forAccount: account)
    }

    public func saveCredential(_ credential: String, forAccount account: String) throws {
        try delegate.saveCredential(credential, forAccount: account)
    }

    public func deleteCredential(forAccount account: String) throws {
        try delegate.deleteCredential(forAccount: account)
    }

    private func readFirstUsableAuthFile() -> String? {
        for url in authFileURLs {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  containsAccessToken(contents) else {
                continue
            }
            return contents
        }
        return nil
    }

    private func containsAccessToken(_ contents: String) -> Bool {
        guard let data = contents.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let token = object["accessToken"] as? String, !token.isEmpty {
            return true
        }
        if let token = object["access_token"] as? String, !token.isEmpty {
            return true
        }
        if let tokens = object["tokens"] as? [String: Any],
           let token = tokens["access_token"] as? String,
           !token.isEmpty {
            return true
        }
        return false
    }

    private static func defaultAuthFileURLs() -> [URL] {
        var urls: [URL] = []
        let environment = ProcessInfo.processInfo.environment
        if let codexHome = environment["CODEX_HOME"],
           !codexHome.isEmpty {
            urls.append(URL(fileURLWithPath: codexHome).appending(path: "auth.json"))
        }
        urls.append(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json"))
        return urls
    }
}
