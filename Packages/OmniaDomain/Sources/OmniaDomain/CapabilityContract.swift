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
public protocol TextGenerationContract: CapabilityContract {
    /// Produces the generated text from `request`.
    ///
    /// Typed against the capability value objects and referencing no provider
    /// (ARC-004). Every failure is expressed in the capability errors of
    /// DES-009 §3.11.2; nothing fails silently (ARC-001).
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse
}

/// Conversation: multi-turn interaction with context (ARC-004).
///
/// Realized by this contract (DES-009 §3.1).
public protocol ConversationContract: CapabilityContract {
    /// Sends `request` and returns the assistant's reply, to be appended to the
    /// history.
    ///
    /// Typed against the capability value objects and referencing no provider
    /// (ARC-004). Every failure is expressed in the capability errors of
    /// DES-009 §3.11.2; nothing fails silently (ARC-001).
    func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse
}

/// Streaming: incremental delivery of generated content (ARC-004).
///
/// Realized by this contract (DES-009 §3.1).
public protocol StreamingContract: CapabilityContract {
    /// Streams the reply to `request` as incremental updates.
    ///
    /// The stream delivers content deltas and ends with the completion event
    /// carrying the assembled assistant message or, on interruption, the
    /// interruption event carrying the preserved partial content (ARC-001,
    /// DES-009 §3.3). Typed against the capability value objects and referencing
    /// no provider (ARC-004). Every failure is expressed in the capability
    /// errors of DES-009 §3.11.2; nothing fails silently (ARC-001).
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error>
}

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
