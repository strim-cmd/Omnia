import OmniaFoundation

/// The identity kind of a stored credential.
///
/// The kind binds `CredentialReference` to the credential concept and is never
/// part of the reference's value (DES-002).
public struct CredentialReferenceKind: IdentifierKind {}

/// A pointer to credentials held in secure storage; never the credentials
/// themselves (ARC-005, ARC-009).
///
/// Built on the Foundation `Identifier` primitive (DES-002), it is opaque,
/// immutable, and serializes to a single canonical string. The value is the
/// reference; the credentials it points to are held by OmniaInfrastructure and
/// never enter the Domain.
public typealias CredentialReference = Identifier<CredentialReferenceKind>
