#if canImport(Security)

import Foundation
import Security
import OmniaDomain

/// The Keychain `CredentialStorageBackend` for Apple platforms (DES-010 §3.4,
/// ARC-005).
///
/// Stores each credential under its `CredentialReference` canonical string in
/// the system Keychain (`kSecClassGenericPassword`). Underlying Keychain
/// failures are translated into the Domain terms: `credentialNotFound` when no
/// credential is stored for the reference and `storageUnavailable` when the
/// Keychain cannot be reached (DES-009 §3.9). Storing replaces the previous
/// value in place, so a failed replace never destroys the stored credential.
/// Secrets never enter logs or analytics; they pass through
/// `Credential.withValue` only (ARC-001).
internal struct KeychainCredentialStorageBackend: CredentialStorageBackend {
    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        try credential.withValue { secret in
            let data = Data(secret.utf8)
            var attributes = baseQuery(for: reference)
            attributes[kSecValueData as String] = data
            switch SecItemAdd(attributes as CFDictionary, nil) {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                guard SecItemUpdate(
                    baseQuery(for: reference) as CFDictionary,
                    [kSecValueData as String: data] as CFDictionary
                ) == errSecSuccess else {
                    throw CredentialStorageError.storageUnavailable
                }
            default:
                throw CredentialStorageError.storageUnavailable
            }
        }
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        var query = baseQuery(for: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let secret = String(data: data, encoding: .utf8)
            else {
                throw CredentialStorageError.storageUnavailable
            }
            return Credential(secret: secret)
        case errSecItemNotFound:
            throw CredentialStorageError.credentialNotFound
        default:
            throw CredentialStorageError.storageUnavailable
        }
    }

    func removeCredential(for reference: CredentialReference) async throws {
        switch SecItemDelete(baseQuery(for: reference) as CFDictionary) {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw CredentialStorageError.storageUnavailable
        }
    }

    /// The generic-password query identifying the credential for `reference`.
    private func baseQuery(for reference: CredentialReference) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.omnia.credentials",
            kSecAttrAccount as String: reference.canonicalString,
        ]
    }
}

#endif
