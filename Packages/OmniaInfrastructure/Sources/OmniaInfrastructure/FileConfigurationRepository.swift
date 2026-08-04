import Foundation
import OmniaDomain

/// The stored representation of one configuration value (DES-010 §3.3).
///
/// The payload is the value's JSON text. The value is type-erased at the
/// storage boundary: the frozen Domain contract leaves `Value` unconstrained
/// (`Equatable & Sendable`), so a repository witness cannot require `Codable`
/// and the concrete type is instead carried by the JSON payload itself
/// (DES-009 §3.5–§3.6).
internal struct ConfigurationStoredValue: Codable, Sendable {
    let payload: String
}

/// The concrete `ConfigurationRepository` over the file-based storage engine
/// (DES-010 §3.1, ARC-005).
///
/// The repository stores, reads, and removes typed configuration values per
/// `ConfigurationKey` and `ConfigurationLevel` (DES-009 §3.5–§3.6). Each value
/// is persisted as a readable, deterministic JSON document — its payload
/// addressed by a document key composed of the level's serialized name and the
/// key's name — through the storage engine (DES-010 §3.2). It owns no business
/// rules (ARC-005): resolution across levels belongs to
/// `ConfigurationResolutionPolicy`, never to this repository (DES-009 §3.6).
/// Stored data remains user-owned, exportable, and removable by the user
/// (ARC-005).
///
/// The repository stores configuration data only, never credentials or secrets;
/// a stored value may hold a `CredentialReference` pointer (ARC-005). Every
/// storage failure — including a value type that cannot be serialized — is
/// surfaced as `RepositoryError.storageUnavailable` (DES-009 §3.9).
///
/// The repository owns its document directory: each repository type must root
/// its store in its own directory, because documents are addressed by key alone
/// and different aggregates must not share a namespace.
public final class FileConfigurationRepository: ConfigurationRepository, Sendable {
    private let store: JSONDocumentStore

    /// Creates a repository rooted at `directory`, which holds its JSON
    /// documents. The directory is created lazily on the first save.
    public init(directory: URL) {
        self.store = JSONDocumentStore(directoryURL: directory)
    }

    /// Stores `value` for `key` at `level`, replacing any previously stored
    /// value for the same key at the same level.
    public func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        guard let encodable = value as? any Encodable else {
            throw RepositoryError.storageUnavailable
        }
        let document = ConfigurationStoredValue(payload: try Self.jsonText(of: encodable))
        try store.save(document, key: Self.documentKey(level: level, keyName: key.name))
    }

    /// Returns the value stored for `key` at `level`, or `nil` when unset.
    public func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        guard
            let document: ConfigurationStoredValue = try store.load(
                key: Self.documentKey(level: level, keyName: key.name)
            )
        else {
            return nil
        }
        guard let data = document.payload.data(using: .utf8) else {
            throw RepositoryError.storageUnavailable
        }
        return try Self.decode(Value.self, from: data)
    }

    /// Removes the value stored for `key` at `level`.
    ///
    /// Removing an unset key is not an error; the operation is idempotent.
    public func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        try store.delete(key: Self.documentKey(level: level, keyName: key.name))
    }

    /// Encodes a type-erased value to its deterministic JSON text.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the value cannot be
    ///   serialized.
    private static func jsonText(of value: any Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    /// Decodes the stored JSON text into `Value`.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the value type cannot
    ///   be restored or the stored payload is not a valid representation.
    private static func decode<Value: Equatable & Sendable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        guard let decodableType = type as? any Decodable.Type else {
            throw RepositoryError.storageUnavailable
        }
        do {
            guard let value = try JSONDecoder().decode(decodableType, from: data) as? Value else {
                throw RepositoryError.storageUnavailable
            }
            return value
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    /// The document key of a stored value: the level's serialized name, then
    /// the key's name. Level serialized names contain no separators, so the
    /// composed form is unambiguous (DES-004 §4).
    private static func documentKey(level: ConfigurationLevel, keyName: String) -> String {
        "\(level.serializedName)-\(keyName)"
    }
}
