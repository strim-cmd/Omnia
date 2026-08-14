import Foundation
import OmniaDomain

/// The concrete `ConversationRepository` over the file-based storage engine and
/// the Conversation serializer (DES-010 §3.1, ARC-005).
///
/// The repository stores and restores the whole Conversation aggregate —
/// including its full message history and its streaming state — by identity
/// through the storage engine, which persists the serializer's DTO as a single
/// JSON document (DES-010 §3.2, DES-009 §3.3). It owns no business rules
/// (ARC-005): the aggregate is stored and restored exactly as the Domain
/// defines it, and the stored history remains user-owned, exportable, and
/// removable by the user (ARC-005). Every storage failure is surfaced as
/// `RepositoryError.storageUnavailable` (DES-009 §3.9).
///
/// The repository owns its document directory: each repository type must root
/// its store in its own directory, because documents are addressed by identity
/// key alone and different aggregates must not share a namespace.
public final class FileConversationRepository: ConversationRepository, Sendable {
    private let store: JSONDocumentStore
    private let serializer: ConversationSerializer

    /// Creates a repository rooted at `directory`, which holds its JSON
    /// documents. The directory is created lazily on the first save.
    public init(directory: URL) {
        self.store = JSONDocumentStore(directoryURL: directory)
        self.serializer = ConversationSerializer()
    }

    /// Saves `conversation`, replacing any previously stored value with the
    /// same identity.
    public func save(_ conversation: Conversation) async throws {
        try store.save(serializer.toDTO(conversation), key: conversation.identity.canonicalString)
    }

    /// Returns the conversation with `identity`, or `nil` when none is stored.
    public func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        guard let dto: ConversationDTO = try store.load(key: identity.canonicalString) else {
            return nil
        }
        return try serializer.fromDTO(dto)
    }

    /// Returns every stored conversation in stable identity order. This
    /// Infrastructure-only maintenance surface supports attachment reference
    /// audits without widening the Domain repository contract.
    public func allConversations() async throws -> [Conversation] {
        var conversations: [Conversation] = []
        for key in try store.allKeys() {
            guard let dto: ConversationDTO = try store.loadRecoveringInvalid(key: key) else {
                continue
            }
            do {
                conversations.append(try serializer.fromDTO(dto))
            } catch {
                // A structurally valid document with invalid aggregate fields
                // is isolated just like malformed JSON during a list scan.
                continue
            }
        }
        return conversations
    }

    /// Removes the stored conversation with `identity`.
    ///
    /// Removing a conversation that is not stored is not an error; the
    /// operation is idempotent.
    public func delete(_ identity: ConversationIdentity) async throws {
        try store.delete(key: identity.canonicalString)
    }

    /// Removes every stored conversation document, including an individually
    /// malformed record that collection recovery intentionally isolates.
    /// This concrete maintenance surface is used only by explicit Clear Data.
    public func removeAll() async throws {
        try store.deleteAll()
    }
}
