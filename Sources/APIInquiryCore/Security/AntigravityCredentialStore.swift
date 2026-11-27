import Foundation

/// Supplies the Antigravity provider with a live local session, in the credential slot.
///
/// `BalanceRefreshController` answers "not configured" whenever the credential is empty and
/// never calls the provider, so a provider that reads its own local server still has to hand
/// the chain something non-empty. This decorator is that something: it reads the daemon file
/// and encodes the port and token into the credential value, which the provider decodes again
/// in `fetchSnapshot(apiKey:)`.
///
/// Nothing is written to the Keychain. The value is minted on every read because the token
/// rotates with the language server process, so caching it would be wrong rather than merely
/// stale.
public final class AntigravityCredentialStore: CredentialStore, LocalConfigurationProviding {
    public static let defaultAntigravityAccount = "antigravity-local-session"

    private let delegate: CredentialStore
    private let antigravityAccount: String
    private let sessionReader: AntigravitySessionReader

    public init(
        delegate: CredentialStore,
        antigravityAccount: String = AntigravityCredentialStore.defaultAntigravityAccount,
        sessionReader: AntigravitySessionReader = AntigravitySessionReader()
    ) {
        self.delegate = delegate
        self.antigravityAccount = antigravityAccount
        self.sessionReader = sessionReader
    }

    public func credential(forAccount account: String) throws -> String? {
        guard account == antigravityAccount else {
            // Forward what this layer does not own. Answering nil here would hide another
            // provider's credential whenever this store sits above it in the chain (#83).
            return try delegate.credential(forAccount: account)
        }

        guard let session = try? sessionReader.readSession() else {
            // Antigravity is not running. Answering nil is what makes the Console say
            // "not configured", and the refresh controller skips the provider entirely —
            // which is the correct outcome, but the wrong wording. The provider reports the
            // reason once it is reachable; see `AntigravityQuotaProvider`.
            return nil
        }

        return AntigravitySessionPayload.encode(session)
    }

    /// Writes go to the delegate only, and never for this provider: its credential belongs to
    /// Antigravity's own login, which this app must not rewrite.
    public func saveCredential(_ credential: String, forAccount account: String) throws {
        try delegate.saveCredential(credential, forAccount: account)
    }

    public func deleteCredential(forAccount account: String) throws {
        try delegate.deleteCredential(forAccount: account)
    }

    /// Points the Console's "open configuration" at the file the user actually edits.
    ///
    /// The daemon file is a runtime artifact that comes and goes with the process, so the
    /// settings file beside it is the better destination; the directory stands in when the
    /// file itself has not been created yet.
    public func configurationURL(for providerID: ProviderID) -> URL? {
        guard providerID == .antigravity else {
            return (delegate as? LocalConfigurationProviding)?.configurationURL(for: providerID)
        }

        let configDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".gemini/config")
        let configFile = configDirectory.appending(path: "config.json")

        if FileManager.default.fileExists(atPath: configFile.path) {
            return configFile
        }
        if FileManager.default.fileExists(atPath: configDirectory.path) {
            return configDirectory
        }
        return nil
    }
}
