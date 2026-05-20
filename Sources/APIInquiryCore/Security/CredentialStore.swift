import Foundation
import Security

public protocol CredentialStore {
    func credential(forAccount account: String) throws -> String?
    func saveCredential(_ credential: String, forAccount account: String) throws
    func deleteCredential(forAccount account: String) throws
}

public enum CredentialStoreError: Error, Equatable, LocalizedError {
    case invalidCredentialData
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentialData:
            return "Credential data could not be encoded or decoded."
        case .unexpectedStatus(let status):
            return "Keychain returned unexpected status \(status)."
        }
    }
}

public extension CredentialStoreError {
    func localizedDescription(strings: LocalizedStrings) -> String {
        switch self {
        case .invalidCredentialData:
            return strings.credentialDataCodingFailed
        case .unexpectedStatus(let status):
            return strings.keychainUnexpectedStatus(status)
        }
    }
}

public final class KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "APIInquiry") {
        self.service = service
    }

    public func credential(forAccount account: String) throws -> String? {
        var query = baseQuery(forAccount: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let credential = String(data: data, encoding: .utf8) else {
                throw CredentialStoreError.invalidCredentialData
            }
            return credential
        case errSecItemNotFound:
            return nil
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func saveCredential(_ credential: String, forAccount account: String) throws {
        guard let data = credential.data(using: .utf8) else {
            throw CredentialStoreError.invalidCredentialData
        }

        var item = baseQuery(forAccount: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try updateCredentialData(data, forAccount: account)
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func deleteCredential(forAccount account: String) throws {
        let status = SecItemDelete(baseQuery(forAccount: account) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func updateCredentialData(_ data: Data, forAccount account: String) throws {
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(forAccount: account) as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(forAccount account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class InMemoryCredentialStore: CredentialStore {
    private var credentialsByAccount: [String: String]

    public init(credentialsByAccount: [String: String] = [:]) {
        self.credentialsByAccount = credentialsByAccount
    }

    public func credential(forAccount account: String) throws -> String? {
        credentialsByAccount[account]
    }

    public func saveCredential(_ credential: String, forAccount account: String) throws {
        credentialsByAccount[account] = credential
    }

    public func deleteCredential(forAccount account: String) throws {
        credentialsByAccount.removeValue(forKey: account)
    }
}
