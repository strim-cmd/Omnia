/// The repository contract for the `Conversation` aggregate and its message
/// history (DES-009 §3.5, ARC-003 Repository).
///
/// The contract hides the storage implementation: consumers depend on this
/// protocol, never on a storage technology (ARC-003). It stores and restores
/// the whole aggregate — including its full message history — by identity and
/// owns no business rules (ARC-005). The stored history is user-owned and
/// remains exportable and removable by the user (ARC-005).
///
/// Implementations belong to OmniaInfrastructure and are delivered by the
/// Composition Root; they are out of scope for this package (ARC-002, ARC-006,
/// ARC-009).
public protocol ConversationRepository: Sendable {
    /// Saves `conversation`, replacing any previously stored value with the
    /// same identity.
    func save(_ conversation: Conversation) async throws

    /// Returns the conversation with `identity`, or `nil` when none is stored.
    func conversation(with identity: ConversationIdentity) async throws -> Conversation?

    /// Removes the stored conversation with `identity`.
    ///
    /// Removing a conversation that is not stored is not an error; the
    /// operation is idempotent.
    func delete(_ identity: ConversationIdentity) async throws
}
