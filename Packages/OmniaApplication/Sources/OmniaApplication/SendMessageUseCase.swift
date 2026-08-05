import OmniaDomain

/// The send-message use case: the streaming orchestration flow of the
/// Conversation module (DES-011 §3.3).
///
/// The use case builds the capability request from the preserved conversation
/// history, selects the provider and model through the Domain
/// `ProviderSelectionService`, delivers the Domain `StreamingUpdate` events to
/// the caller incrementally, appends and persists the assembled assistant
/// message on completion, and preserves partial content on interruption —
/// never discarding it (ARC-001, DES-009 §3.3, §3.11).
///
/// It consumes only the Domain contracts — the streaming capability contract,
/// the selection service, and the conversation repository — and every
/// collaborator is injected by the Composition Root (ARC-006). It owns no
/// business rules: the `Conversation` aggregate owns the history and
/// streaming-state invariants, and the use case only sequences the operations
/// (ARC-002, ADR-0001). It delivers exactly the events the Domain declares and
/// invents no stream lifecycle of its own (DES-011 §3.3, DES-009 §3.11.4).
///
/// The user message is appended to the conversation and persisted before the
/// stream begins; the history that reaches the provider is the persisted
/// history (DES-011 §3.3). A failed provider selection surfaces as the Domain
/// `CapabilityError.providerUnavailable`, and capability and credential
/// failures surface as their Domain errors, never wrapped (DES-009 §3.2, §3.9).
///
/// Input is validated at the boundary (ARC-009): an empty user message and a
/// conversation that is not stored are rejected with the typed application
/// error of DES-011 §3.6 before any domain operation.
public struct SendMessageUseCase: Sendable {
    private let streamingContract: any StreamingContract
    private let selectionService: ProviderSelectionService
    private let conversationRepository: any ConversationRepository

    /// Creates a send-message use case over the given Domain contracts.
    public init(
        streamingContract: any StreamingContract,
        selectionService: ProviderSelectionService,
        conversationRepository: any ConversationRepository
    ) {
        self.streamingContract = streamingContract
        self.selectionService = selectionService
        self.conversationRepository = conversationRepository
    }

    /// Performs the streaming flow for `request` and delivers the Domain
    /// `StreamingUpdate` events incrementally (DES-011 §3.3).
    ///
    /// The user message is appended and persisted before the returned stream
    /// is produced. The provider and model are selected through the Domain
    /// selection service; a failed selection throws
    /// `CapabilityError.providerUnavailable`. The returned stream delivers the
    /// capability stream's events, appends and persists the assembled assistant
    /// message on completion, and preserves partial content as interrupted on
    /// interruption — the conversation is marked interrupted and carries the
    /// partial content forward (ARC-001, DES-009 §3.3, §3.11.4).
    ///
    /// Streaming-phase failures surface as the Domain errors that caused them —
    /// `CapabilityError` or `CredentialStorageError`, never wrapped — and
    /// repository failures surface as `RepositoryError` (§3.6, DES-009 §3.9).
    public func send(
        _ request: SendMessageRequest
    ) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        try validate(request)
        guard var conversation = try await conversationRepository.conversation(with: request.conversation) else {
            throw ApplicationValidationError.invalid(reason: "The conversation is not stored.")
        }
        try conversation.append(request.message)
        try await conversationRepository.save(conversation)
        let selection = await selectionService.select(
            requiredCapability: .streaming,
            userSelection: request.userSelection,
            workspacePreference: request.workspacePreference,
            capabilityPreference: request.capabilityPreference
        )
        guard case let .selected(provider: _, model: model) = selection else {
            throw CapabilityError.providerUnavailable
        }
        try conversation.beginStreaming()
        return makeStream(initialConversation: conversation, model: model)
    }

    /// Validates the request at the application boundary (ARC-009, DES-011 §3.6).
    private func validate(_ request: SendMessageRequest) throws {
        guard !request.message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The user message is empty.")
        }
    }

    /// Builds the stream that consumes the capability stream, forwards its
    /// events, and persists the terminal aggregate state (DES-011 §3.3).
    private func makeStream(
        initialConversation: Conversation,
        model: ModelReference
    ) -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var conversation = initialConversation
                let request = StreamingRequest(
                    identity: CapabilityRequestIdentity(),
                    history: conversation.history,
                    model: model
                )
                do {
                    let capabilityStream = try await streamingContract.stream(request)
                    var terminated = false
                    for try await update in capabilityStream {
                        try await apply(update, to: &conversation)
                        if case .completion = update {
                            terminated = true
                        } else if case .interruption = update {
                            terminated = true
                        }
                        guard !Task.isCancelled else {
                            try? await interruptAndPersist(&conversation)
                            return
                        }
                        continuation.yield(update)
                    }
                    guard terminated else {
                        // The stream ended without a terminal event; the Domain
                        // declares this failure and its preserved partial
                        // content (DES-009 §3.11.4).
                        let partial = conversation.partialContent ?? ""
                        try? await interruptAndPersist(&conversation)
                        guard !Task.isCancelled else { return }
                        continuation.finish(
                            throwing: CapabilityError.streamingInterrupted(partialContent: partial)
                        )
                        return
                    }
                    guard !Task.isCancelled else { return }
                    continuation.finish()
                } catch is CancellationError {
                    try? await interruptAndPersist(&conversation)
                    guard !Task.isCancelled else { return }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    try? await preserveForFailure(&conversation, error: error)
                    guard !Task.isCancelled else { return }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Applies `update` to the conversation, persisting the terminal state
    /// (DES-009 §3.3). Content deltas extend the partial content; the terminal
    /// events are persisted before they are forwarded.
    private func apply(_ update: StreamingUpdate, to conversation: inout Conversation) async throws {
        switch update {
        case .contentDelta(_, let content):
            try conversation.appendPartial(content)
        case .completion(_, let message):
            try reconcilePartial(&conversation, to: message.content)
            try conversation.completeStreaming()
            try await conversationRepository.save(conversation)
        case .interruption(_, let partialContent):
            try reconcilePartial(&conversation, to: partialContent)
            try conversation.interruptStreaming()
            try await conversationRepository.save(conversation)
        }
    }

    /// Preserves the partial content the failure reports and marks the
    /// conversation interrupted (ARC-001). The partial content received so far
    /// is never discarded; on a resume the carried content is preserved too
    /// (DES-009 §3.3, §3.11.4).
    private func preserveForFailure(_ conversation: inout Conversation, error: any Error) async throws {
        if case CapabilityError.streamingInterrupted(let partial) = error {
            try reconcilePartial(&conversation, to: partial)
        }
        try await interruptAndPersist(&conversation)
    }

    /// Marks the conversation interrupted, preserving the accumulated partial
    /// content, and persists it (DES-009 §3.3).
    private func interruptAndPersist(_ conversation: inout Conversation) async throws {
        try conversation.interruptStreaming()
        try await conversationRepository.save(conversation)
    }

    /// Extends the conversation's partial content to `content` when the target
    /// extends the accumulated content as a prefix; otherwise the accumulated
    /// content is left unchanged, never discarded (ARC-001).
    private func reconcilePartial(_ conversation: inout Conversation, to content: String) throws {
        guard let partial = conversation.partialContent,
              content.hasPrefix(partial),
              content.count > partial.count
        else {
            return
        }
        try conversation.appendPartial(String(content.dropFirst(partial.count)))
    }
}
