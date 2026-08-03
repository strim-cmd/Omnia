import OmniaFoundation

/// The identity kind of a workspace.
///
/// The kind binds `WorkspaceIdentity` to the workspace concept and is never
/// part of the identifier's value (DES-002).
public struct WorkspaceIdentityKind: IdentifierKind {}

/// A stable identity of a workspace within the application (DES-009 §3.4).
///
/// Built on the Foundation `Identifier` primitive (DES-002), it is the shared
/// identity used for cross-aggregate references to the workspace. It is
/// immutable, compares by content, and serializes to a single canonical string.
public typealias WorkspaceIdentity = Identifier<WorkspaceIdentityKind>
