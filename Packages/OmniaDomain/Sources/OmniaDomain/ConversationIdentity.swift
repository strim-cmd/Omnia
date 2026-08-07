import OmniaFoundation

/// The identity kind of a conversation.
///
/// The kind binds `ConversationIdentity` to the conversation concept and is
/// never part of the identifier's value (DES-002).
public struct ConversationIdentityKind: IdentifierKind {}

/// A stable identity of a conversation within the application (DES-009 §3.3).
///
/// Built on the Foundation `Identifier` primitive (DES-002), it is the shared
/// identity used for cross-aggregate references to the conversation. It is
/// immutable, compares by content, and serializes to a single canonical string.
public typealias ConversationIdentity = Identifier<ConversationIdentityKind>
