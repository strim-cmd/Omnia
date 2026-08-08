import OmniaFoundation

/// The identity kind of a capability request.
///
/// The kind binds `CapabilityRequestIdentity` to the capability request concept
/// and is never part of the identifier's value (DES-002).
public struct CapabilityRequestIdentityKind: IdentifierKind {}

/// A stable identity of a capability request (DES-009 §3.11.1).
///
/// Built on the Foundation `Identifier` primitive (DES-002), it correlates a
/// response or a streaming update to its request. It is immutable, compares by
/// content, and serializes to a single canonical string.
public typealias CapabilityRequestIdentity = Identifier<CapabilityRequestIdentityKind>
