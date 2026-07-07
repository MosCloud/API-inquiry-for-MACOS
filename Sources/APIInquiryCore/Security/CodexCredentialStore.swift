import Foundation

public enum CodexAuthFileStatus: Equatable {
    case missing
    case usable(URL)
    case malformed(URL)
    case missingAccessToken(URL)
}

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

    public func codexConfigTargetURL() -> URL? {
        if let existingAuthFileURL = firstExistingAuthFileURL() {
            return existingAuthFileURL
        }

        guard let configDirectoryURL = authFileURLs.first?.deletingLastPathComponent() else {
            return nil
        }

        if FileManager.default.fileExists(atPath: configDirectoryURL.path) {
            return URL(fileURLWithPath: configDirectoryURL.path)
        }

        return nil
    }

    public func codexAuthFileStatus() -> CodexAuthFileStatus {
        var firstUnusableStatus: CodexAuthFileStatus?

        for url in authFileURLs {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            let status = codexAuthFileStatus(at: url)
            if case .usable = status {
                return status
            }

            if firstUnusableStatus == nil {
                firstUnusableStatus = status
            }
        }

        return firstUnusableStatus ?? .missing
    }

    public func codexConfigTargetURLCreatingDirectoryIfNeeded() -> URL? {
        if let existingTargetURL = codexConfigTargetURL() {
            return existingTargetURL
        }

        guard let configDirectoryURL = authFileURLs.first?.deletingLastPathComponent() else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: configDirectoryURL,
                withIntermediateDirectories: true
            )
            return URL(fileURLWithPath: configDirectoryURL.path)
        } catch {
            return nil
        }
    }

    private func readFirstUsableAuthFile() -> String? {
        for url in authFileURLs {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let object = authObject(from: contents),
                  containsAccessToken(in: object) else {
                continue
            }
            return contents
        }
        return nil
    }

    private func firstExistingAuthFileURL() -> URL? {
        authFileURLs.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func codexAuthFileStatus(at url: URL) -> CodexAuthFileStatus {
        guard let contents = try? String(contentsOf: url, encoding: .utf8),
              let object = authObject(from: contents) else {
            return .malformed(url)
        }

        return containsAccessToken(in: object) ? .usable(url) : .missingAccessToken(url)
    }

    private func authObject(from contents: String) -> [String: Any]? {
        guard let data = contents.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func containsAccessToken(in object: [String: Any]) -> Bool {
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
