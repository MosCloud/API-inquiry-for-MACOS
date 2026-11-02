import CryptoKit
import Foundation

/// Opens the WorkBuddy desktop app's at-rest encrypted credential fields.
///
/// From WorkBuddy 5.6.0 the desktop app no longer writes `auth.accessToken` /
/// `auth.refreshToken` as plain strings. Each becomes a field wrapper:
///
/// ```json
/// { "$wbEncrypted": 1, "envelope": "<base64 of a JSON envelope>" }
/// ```
///
/// and the envelope is `{suite, keyId, nonce, authTag, ciphertext}` for AES-256-GCM
/// with a 12-byte nonce and a 16-byte tag. A reader that only accepts strings sees no
/// credential at all and reports the account as signed out, which is why this exists.
///
/// The key is **not** a user secret: it is a build-time constant compiled into the
/// app's own Electron native module. Rather than freeze a copy of that constant here
/// (it would rot the moment WorkBuddy ships a new build), this asks the very build
/// that wrote the file, by running the app's binary as plain Node and calling into
/// the binding that owns the value.
///
/// Verified against WorkBuddy 5.9.3 on macOS 2026-11-02: the key payload is
/// `{version, atRestSecretKey, atRestDeveloperPublicKey}`, and the full chain
/// (key → derive → decrypt) yields a working JWT.
public enum WorkBuddyCredentialDecoder {
    /// Domain separator the AAD transcript starts with.
    private static let aadDomain = Data("WB-AAD\0".utf8)

    /// Format identifier the AAD transcript carries for FIELD-framed envelopes.
    private static let fieldFormatID = "WBEV1"

    /// Scheme name of the symmetric envelope this decoder opens.
    private static let symmetricScheme = "sym-v1"

    /// Framing code for FIELD framing, transcribed into the AAD.
    private static let fieldFramingCode: UInt8 = 2

    /// Bound on asking the app for its key. Long enough for a cold Electron start on a
    /// loaded machine, short enough that a broken install cannot hang a refresh.
    public static let keyFetchTimeout: TimeInterval = 10

    /// An envelope opened successfully, plus the key id it belonged to.
    public struct Envelope: Equatable {
        public let suite: Int
        public let keyID: String
        public let nonce: Data
        public let authTag: Data
        public let ciphertext: Data
    }

    /// Whether a decoded JSON value is the app's encrypted-field wrapper.
    public static func isEncryptedField(_ value: Any) -> Bool {
        guard let wrapper = value as? [String: Any] else { return false }
        guard wrapper.count == 2 else { return false }
        guard let marker = wrapper["$wbEncrypted"] as? Int, marker == 1 else { return false }
        return wrapper["envelope"] is String
    }

    /// Decode the base64 envelope inside a field wrapper.
    public static func parseEnvelope(from wrapper: [String: Any]) throws -> Envelope {
        guard let base64 = wrapper["envelope"] as? String,
              let json = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: json),
              let record = object as? [String: Any] else {
            throw WorkBuddyCredentialError.malformedEnvelope
        }

        guard let suite = record["suite"] as? Int,
              let keyID = record["keyId"] as? String,
              let nonce = Self.base64(record["nonce"]),
              let authTag = Self.base64(record["authTag"]),
              let ciphertext = Self.base64(record["ciphertext"]) else {
            throw WorkBuddyCredentialError.malformedEnvelope
        }

        return Envelope(suite: suite, keyID: keyID, nonce: nonce, authTag: authTag, ciphertext: ciphertext)
    }

    /// Derive the 32-byte field key from the app's key payload JSON.
    ///
    /// The app hashes the payload's base64 **string** — not its decoded bytes — so the
    /// same spelling is required here; hashing the decoded secret produces a different
    /// key and every field fails to open.
    public static func deriveKey(payloadJSON: String) throws -> Data {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let record = object as? [String: Any] else {
            throw WorkBuddyCredentialError.malformedKeyPayload
        }
        guard let secret = record["atRestSecretKey"] as? String, !secret.isEmpty else {
            throw WorkBuddyCredentialError.malformedKeyPayload
        }
        return Data(SHA256.hash(data: Data(secret.utf8)))
    }

    /// The key id a derived key is known by: the first 16 hex characters of its SHA-256.
    public static func keyID(for key: Data) -> String {
        String(SHA256.hash(data: key).map { String(format: "%02x", $0) }.joined().prefix(16))
    }

    /// The authenticated additional data for one FIELD-framed `sym-v1` envelope.
    ///
    /// Every field is length-prefixed (uint32 big-endian) except the single-byte
    /// framing code and the two trailing zero bytes, which stand for an absent
    /// sequence number and an absent final marker. Getting this byte order wrong is
    /// indistinguishable from having the wrong key: GCM fails the tag either way.
    public static func additionalAuthenticatedData(keyID: String, suite: Int) -> Data {
        var data = Data()
        data.append(aadDomain)
        data.append(contentsOf: [1])
        data.append(lengthPrefixed(fieldFormatID))
        data.append(lengthPrefixed(symmetricScheme))
        data.append(uint32(UInt32(truncatingIfNeeded: suite)))
        data.append(lengthPrefixed(keyID))
        data.append(contentsOf: [fieldFramingCode])
        data.append(contentsOf: [0])
        data.append(contentsOf: [0])
        return data
    }

    /// Open one encrypted field and return its plaintext.
    ///
    /// Throws rather than degrading to a truncated token when the envelope is
    /// malformed, belongs to another key, or fails authentication.
    public static func openField(_ wrapper: [String: Any], key: Data) throws -> String {
        let envelope = try parseEnvelope(from: wrapper)
        let expected = keyID(for: key)
        guard envelope.keyID == expected else {
            throw WorkBuddyCredentialError.keyMismatch(expected: expected, found: envelope.keyID)
        }

        let aad = additionalAuthenticatedData(keyID: envelope.keyID, suite: envelope.suite)
        guard let nonce = try? AES.GCM.Nonce(data: envelope.nonce),
              let sealed = try? AES.GCM.SealedBox(
                  nonce: nonce,
                  ciphertext: envelope.ciphertext,
                  tag: envelope.authTag
              ),
              let plaintext = try? AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: aad) else {
            throw WorkBuddyCredentialError.authenticationFailed
        }
        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw WorkBuddyCredentialError.malformedEnvelope
        }
        return text
    }

    /// Decode a base64 field, returning nil for a missing or undecodable one.
    private static func base64(_ value: Any?) -> Data? {
        guard let text = value as? String else { return nil }
        return Data(base64Encoded: text)
    }

    private static func uint32(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }

    private static func lengthPrefixed(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        return uint32(UInt32(bytes.count)) + bytes
    }
}

/// Errors that describe why a WorkBuddy credential could not be read.
///
/// "Signed out" and "signed in, but the credential cannot be opened" resolve to the
/// same observable state — zero usable credentials — and telling a correctly signed-in
/// user to sign in again is the one piece of advice that cannot help. They are separate
/// cases so the UI can say something true.
public enum WorkBuddyCredentialError: Error, Equatable, LocalizedError {
    /// No desktop app auth file exists at the expected path.
    case noAuthFile(path: String)
    /// A field wrapper exists but no key could be obtained to open it.
    case keyUnavailable(reason: String)
    /// The key payload came back, but not in the shape this decoder understands.
    case malformedKeyPayload
    /// The envelope is not a well-formed WorkBuddy field.
    case malformedEnvelope
    /// The envelope belongs to a different key than the one we could derive.
    case keyMismatch(expected: String, found: String)
    /// The field opened but failed GCM authentication.
    case authenticationFailed
    /// The document carried no access token at all.
    case missingAccessToken

    public var errorDescription: String? {
        switch self {
        case .noAuthFile(let path):
            return "No WorkBuddy sign-in was found at \(path)."
        case .keyUnavailable(let reason):
            return "The WorkBuddy sign-in is encrypted and its key could not be obtained: \(reason)"
        case .malformedKeyPayload:
            return "The WorkBuddy app returned an unreadable at-rest key payload."
        case .malformedEnvelope:
            return "The WorkBuddy credential envelope is malformed."
        case .keyMismatch(let expected, let found):
            return "The WorkBuddy credential belongs to key \(found), not the available key \(expected)."
        case .authenticationFailed:
            return "The WorkBuddy credential failed authentication."
        case .missingAccessToken:
            return "The WorkBuddy sign-in carries no access token."
        }
    }

    /// Whether re-signing in can possibly fix this. False for the encrypted-credential
    /// cases, where the real fix is installing (or locating) the desktop app.
    public var isSignInProblem: Bool {
        switch self {
        case .noAuthFile, .missingAccessToken:
            return true
        case .keyUnavailable, .malformedKeyPayload, .malformedEnvelope, .keyMismatch, .authenticationFailed:
            return false
        }
    }
}
