import Foundation

/// Reads the WorkBuddy desktop app's sign-in, so the Console needs no manual copy/paste.
///
/// WorkBuddy keeps its credential at
/// `~/Library/Application Support/CodeBuddyExtension/Data/Public/auth/workbuddy-desktop.info`.
/// Since 5.6.0 the token fields are encrypted at rest, so reading the file is only half
/// the job: `WorkBuddyCredentialDecoder` opens them by asking the installed app for its
/// key. The file is **never** written back — the credential belongs to the desktop app,
/// and v0.4.1 does not refresh it.
///
/// The provider receives a JSON document rather than a bare token, because the billing
/// call needs the account id and domain alongside it.
public final class WorkBuddyCredentialStore: CredentialStore, LocalConfigurationProviding {
    public static let defaultWorkBuddyAccount = "workbuddy-credential"

    /// The desktop app's auth directory, relative to the user's home.
    public static let defaultAuthRelativePath = [
        "Library", "Application Support", "CodeBuddyExtension", "Data", "Public", "auth"
    ]

    /// The live auth file's basename. The app also leaves timestamped backups beside it;
    /// those hold *older* sign-ins, so only the live name is read.
    public static let defaultAuthFileName = "workbuddy-desktop.info"

    private let delegate: CredentialStore
    private let workBuddyAccount: String
    private let authFileURL: URL
    private let authDirectoryURL: URL
    private let appExecutablePath: String?
    private let now: () -> Date

    /// The key is derived once and remembered for the process lifetime.
    ///
    /// It never touches disk; the only copy lives in the app that produced it. The cache
    /// is keyed on the key id so a WorkBuddy upgrade that rotates the key re-derives
    /// automatically instead of failing every read until restart.
    private static var cachedKey: (keyID: String, key: Data)?

    public init(
        delegate: CredentialStore,
        workBuddyAccount: String = WorkBuddyCredentialStore.defaultWorkBuddyAccount,
        authFileURL: URL? = nil,
        authDirectoryURL: URL? = nil,
        appExecutablePath: String? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.delegate = delegate
        self.workBuddyAccount = workBuddyAccount
        self.authDirectoryURL = authDirectoryURL
            ?? Self.defaultAuthDirectoryURL()
        self.authFileURL = authFileURL
            ?? self.authDirectoryURL.appendingPathComponent(Self.defaultAuthFileName)
        self.appExecutablePath = appExecutablePath
        self.now = now
    }

    public static func defaultAuthDirectoryURL() -> URL {
        defaultAuthRelativePath.reduce(FileManager.default.homeDirectoryForCurrentUser) {
            $0.appendingPathComponent($1)
        }
    }

    public func credential(forAccount account: String) throws -> String? {
        guard account == workBuddyAccount else {
            return try delegate.credential(forAccount: account)
        }

        if let stored = try readCredential() {
            return stored
        }
        return try delegate.credential(forAccount: account)
    }

    /// Writes go to the wrapped store only. The desktop app's file is read-only.
    public func saveCredential(_ credential: String, forAccount account: String) throws {
        try delegate.saveCredential(credential, forAccount: account)
    }

    public func deleteCredential(forAccount account: String) throws {
        try delegate.deleteCredential(forAccount: account)
    }

    /// Read the sign-in and serialize it for the provider.
    ///
    /// Returns nil when there is nothing to read — no file, or a file that carries no
    /// token — so the caller falls through to the delegate. A file that exists but
    /// cannot be opened throws instead: that is the "signed in, credentials unreadable"
    /// case, and silently reporting "not configured" would give the user the one piece
    /// of advice that cannot help.
    private func readCredential() throws -> String? {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: authFileURL)
        } catch {
            throw WorkBuddyCredentialError.noAuthFile(path: authFileURL.path)
        }

        guard let document = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let auth = document["auth"] as? [String: Any] ?? [:]
        let account = document["account"] as? [String: Any] ?? [:]

        guard let accessToken = try token(from: auth["accessToken"]) else {
            return nil
        }

        // `account.uid` is the billing identity. It is not secret and the endpoint needs
        // it, so it travels in the credential document rather than being looked up
        // again at request time.
        let userID = (account["uid"] as? String) ?? ""
        let domain = (auth["domain"] as? String) ?? "www.workbuddy.cn"

        let payload: [String: Any] = [
            "accessToken": accessToken,
            "uid": userID,
            "domain": domain,
            "expiresAt": Self.epochMilliseconds(auth["expiresAt"])
        ]
        let serialized = try? JSONSerialization.data(withJSONObject: payload)
        return serialized.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Resolve one token field, decrypting it when the app stored a wrapper.
    ///
    /// A plain string is used as-is. A wrapper needs the at-rest key; when the key
    /// cannot be obtained this throws the encrypted-credential error rather than
    /// returning nil, because "no credential" and "unreadable credential" are different
    /// problems with different fixes.
    private func token(from value: Any?) throws -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard let wrapper = value as? [String: Any],
              WorkBuddyCredentialDecoder.isEncryptedField(wrapper) else {
            return nil
        }

        let key = try resolveKey(expectedKeyID: Self.envelopeKeyID(from: wrapper))
        return try WorkBuddyCredentialDecoder.openField(wrapper, key: key)
    }

    /// Obtain the at-rest key, preferring the in-process cache.
    ///
    /// The envelope names the key it was sealed with, so a cached key can be checked
    /// before it is used: a mismatch means WorkBuddy rotated its key (an upgrade), and
    /// the correct response is to ask the app again rather than to fail.
    private func resolveKey(expectedKeyID: String?) throws -> Data {
        if let cached = Self.cachedKey, expectedKeyID == nil || cached.keyID == expectedKeyID {
            return cached.key
        }

        let payload = try fetchKeyPayload()
        let key = try WorkBuddyCredentialDecoder.deriveKey(payloadJSON: payload)
        Self.cachedKey = (WorkBuddyCredentialDecoder.keyID(for: key), key)
        return key
    }

    private static func envelopeKeyID(from wrapper: [String: Any]) -> String? {
        (try? WorkBuddyCredentialDecoder.parseEnvelope(from: wrapper))?.keyID
    }

    /// Ask the installed app for its key payload.
    ///
    /// The app's binary is run as plain Node (`ELECTRON_RUN_AS_NODE`) and calls into the
    /// native binding that owns the value, so no build-specific constant is frozen into
    /// this app. No stdin, a hard timeout, and stdout is the only thing read.
    private func fetchKeyPayload() throws -> String {
        guard let executable = appExecutablePath ?? Self.locateAppExecutable() else {
            throw WorkBuddyCredentialError.keyUnavailable(reason: "the WorkBuddy desktop app was not found")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        // The binding is the app's own public surface for this value.
        process.arguments = [
            "-e",
            "try{process.stdout.write(process._linkedBinding('electron_browser_workbuddy_storage').loggerGet())}"
                + "catch(e){process.exitCode=3;process.stderr.write(String(e&&e.message||e))}"
        ]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["ELECTRON_RUN_AS_NODE": "1"]
        ) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw WorkBuddyCredentialError.keyUnavailable(reason: error.localizedDescription)
        }

        // A stalled child would block the refresh; kill it rather than wait forever.
        let deadline = Date().addingTimeInterval(WorkBuddyCredentialDecoder.keyFetchTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            throw WorkBuddyCredentialError.keyUnavailable(reason: "the app did not answer in time")
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0,
              let text = String(data: output, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            let message = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw WorkBuddyCredentialError.keyUnavailable(
                reason: message.isEmpty ? "the app returned no key" : message
            )
        }
        return text
    }

    /// The installed desktop app's executable, or nil when it is absent.
    ///
    /// The binary is not named after the app — both WorkBuddy bundles ship a binary
    /// called `Electron` — so the name is read from the bundle's own `Info.plist`
    /// instead of assembled from the app name, and the bundle's identifier is checked
    /// first so another Electron app is never launched by mistake.
    public static func locateAppExecutable() -> String? {
        let bundles = [
            "/Applications/WorkBuddy.app",
            NSHomeDirectory() + "/Applications/WorkBuddy.app"
        ]
        for bundle in bundles {
            let plistURL = URL(fileURLWithPath: bundle).appendingPathComponent("Contents/Info.plist")
            guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else { continue }
            guard (plist["CFBundleIdentifier"] as? String) == "com.tencent.workbuddy.mac" else { continue }
            guard let executable = plist["CFBundleExecutable"] as? String, !executable.isEmpty else { continue }
            let path = URL(fileURLWithPath: bundle)
                .appendingPathComponent("Contents/MacOS")
                .appendingPathComponent(executable)
                .path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Normalize a stored expiry to epoch milliseconds.
    ///
    /// The desktop document writes milliseconds while the plugin-side copies write
    /// seconds, so the unit cannot be assumed: values below 10^12 are seconds.
    public static func epochMilliseconds(_ value: Any?) -> Double {
        let raw: Double?
        switch value {
        case let number as Double:
            raw = number
        case let number as Int:
            raw = Double(number)
        case let text as String:
            raw = Double(text)
        default:
            raw = nil
        }
        guard let raw, raw > 0 else { return 0 }
        return raw > 1_000_000_000_000 ? raw : raw * 1000
    }

    // MARK: - LocalConfigurationProviding

    /// Point 打开配置 at the auth file, or at its directory when the file is absent so a
    /// signed-out user still lands somewhere useful.
    public func configurationURL(for providerID: ProviderID) -> URL? {
        guard providerID == .workbuddy else {
            // Forward to the wrapped store: answering nil for providers this store does
            // not own would silently disable their 打开配置 button (#83).
            return (delegate as? LocalConfigurationProviding)?.configurationURL(for: providerID)
        }
        if FileManager.default.fileExists(atPath: authFileURL.path) {
            return authFileURL
        }
        if FileManager.default.fileExists(atPath: authDirectoryURL.path) {
            return authDirectoryURL
        }
        return nil
    }
}
