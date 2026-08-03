/// The provider-agnostic contract through which providers are consumed
/// (DES-009 §3.1).
///
/// The application depends on this contract, never on a provider (ARC-004): it
/// declares what the application needs, in the application's own terms. A
/// capability is realized only by extending this contract; capabilities MUST
/// NOT be added outside it (ARC-004, ARC-007). Adapters implement the contract
/// in the Infrastructure layer; nothing above the Domain references a provider.
///
/// The realized capabilities of this contract are the conforming protocols
/// `TextGenerationContract`, `ConversationContract`, and `StreamingContract`,
/// enumerated by `Capability.realized`. The capability a contract delivers is
/// expressed by its type; a provider that delivers several capabilities
/// conforms to each contract it realizes. The remaining ARC-004 capabilities
/// are declared as extension points and have no contract in this phase.
public protocol CapabilityContract: Sendable {}

/// Text Generation: producing text from a prompt (ARC-004).
///
/// Realized by this contract (DES-009 §3.1).
public protocol TextGenerationContract: CapabilityContract {}

/// Conversation: multi-turn interaction with context (ARC-004).
///
/// Realized by this contract (DES-009 §3.1).
public protocol ConversationContract: CapabilityContract {}

/// Streaming: incremental delivery of generated content (ARC-004).
///
/// Realized by this contract (DES-009 §3.1).
public protocol StreamingContract: CapabilityContract {}

extension Capability {
    /// The capabilities realized by this contract (DES-009 §3.1): text
    /// generation, conversation, and streaming. The remaining capabilities of
    /// the ARC-004 set are declared as extension points and are not realized.
    public static let realized: Set<Capability> = [
        .textGeneration,
        .conversation,
        .streaming,
    ]
}
