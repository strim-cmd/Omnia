/// The repository contract for the `Provider` model (DES-009 §3.5, ARC-003
/// Repository).
///
/// The contract hides the storage implementation: consumers depend on this
/// protocol, never on a storage technology (ARC-003). It stores and restores
/// the provider — its declared connection and its lifecycle state — by
/// identity and owns no business rules (ARC-005).
///
/// Credentials are isolated from application data: the stored provider never
/// carries credentials (ARC-004, ARC-005). Stored data is user-owned and
/// remains exportable and removable by the user (ARC-005).
///
/// Implementations belong to OmniaInfrastructure and are delivered by the
/// Composition Root; they are out of scope for this package (ARC-002, ARC-006,
/// ARC-009).
public protocol ProviderRepository: Sendable {
    /// Saves `provider`, replacing any previously stored value with the same
    /// identity.
    func save(_ provider: Provider) async throws

    /// Returns the provider with `identity`, or `nil` when none is stored.
    func provider(with identity: ProviderIdentity) async throws -> Provider?

    /// Returns all stored providers.
    func allProviders() async throws -> [Provider]

    /// Removes the stored provider with `identity`.
    ///
    /// Removing a provider that is not stored is not an error; the operation
    /// is idempotent.
    func delete(_ identity: ProviderIdentity) async throws
}
