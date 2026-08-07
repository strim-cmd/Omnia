import OmniaFoundation

/// The identity kind of a provider.
///
/// The kind binds `ProviderIdentity` to the provider concept and is never part
/// of the identifier's value (DES-002).
public struct ProviderIdentityKind: IdentifierKind {}

/// A stable identity of a provider within the application (ARC-004).
///
/// Built on the Foundation `Identifier` primitive (DES-002), it is the shared
/// identity used for cross-aggregate references to the provider (DES-009
/// §3.1). It is immutable, compares by content, and serializes to a single
/// canonical string.
public typealias ProviderIdentity = Identifier<ProviderIdentityKind>
