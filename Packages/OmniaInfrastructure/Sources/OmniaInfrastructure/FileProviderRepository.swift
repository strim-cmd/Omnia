import Foundation
import OmniaDomain

/// The concrete `ProviderRepository` over the file-based storage engine and
/// the Provider serializer (DES-010 §3.1, ARC-005).
///
/// The repository stores and restores the Provider aggregate — its declared
/// connection and its lifecycle state — by identity through the storage engine,
/// which persists the serializer's DTO as a single JSON document (DES-010
/// §3.2). It owns no business rules (ARC-005): the aggregate is stored and
/// restored exactly as the Domain defines it, and stored data remains
/// exportable and removable by the user (ARC-005). The stored provider never
/// carries credentials — only the connection's declared data (ARC-004,
/// ARC-005). Every storage failure is surfaced as
/// `RepositoryError.storageUnavailable` (DES-009 §3.9).
///
/// The repository owns its document directory: each repository type must root
/// its store in its own directory, because documents are addressed by identity
/// key alone and different aggregates must not share a namespace.
public final class FileProviderRepository: ProviderRepository, Sendable {
    private let store: JSONDocumentStore
    private let serializer: ProviderSerializer

    /// Creates a repository rooted at `directory`, which holds its JSON
    /// documents. The directory is created lazily on the first save.
    public init(directory: URL) {
        self.store = JSONDocumentStore(directoryURL: directory)
        self.serializer = ProviderSerializer()
    }

    /// Saves `provider`, replacing any previously stored value with the same
    /// identity.
    public func save(_ provider: Provider) async throws {
        try store.save(serializer.toDTO(provider), key: provider.identity.canonicalString)
    }

    /// Returns the provider with `identity`, or `nil` when none is stored.
    public func provider(with identity: ProviderIdentity) async throws -> Provider? {
        guard let dto: ProviderDTO = try store.load(key: identity.canonicalString) else {
            return nil
        }
        return try serializer.fromDTO(dto)
    }

    /// Returns all stored providers, in a stable order.
    public func allProviders() async throws -> [Provider] {
        var providers: [Provider] = []
        for key in try store.allKeys() {
            guard let dto: ProviderDTO = try store.load(key: key) else { continue }
            providers.append(try serializer.fromDTO(dto))
        }
        return providers
    }

    /// Removes the stored provider with `identity`.
    ///
    /// Removing a provider that is not stored is not an error; the operation is
    /// idempotent.
    public func delete(_ identity: ProviderIdentity) async throws {
        try store.delete(key: identity.canonicalString)
    }
}
