import Foundation
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
    private let resolveAttachments: @Sendable (
        [Message],
        ProviderModelSelection
    ) async throws -> [ResolvedAttachment]
    private let now: @Sendable () -> Date

    /// Creates a send-message use case over the given Domain contracts.
    public init(
        streamingContract: any StreamingContract,
        selectionService: ProviderSelectionService,
        conversationRepository: any ConversationRepository,
        resolveAttachments: @escaping @Sendable (
            [Message],
            ProviderModelSelection
        ) async throws -> [ResolvedAttachment] = { _, _ in [] },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.streamingContract = streamingContract
        self.selectionService = selectionService
        self.conversationRepository = conversationRepository
        self.resolveAttachments = resolveAttachments
        self.now = now
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
        let prepared = try await prepareSend(request)
        return makeStream(
            initialConversation: prepared.conversation,
            selection: prepared.selection,
            resolvedAttachments: prepared.attachments
        )
    }

    /// Resumes the interrupted response of a conversation, delivering the
    /// Domain `StreamingUpdate` events incrementally (DES-011 §3.3, DES-009
    /// §3.3, §3.11.4).
    ///
    /// A resume re-sends the last prompt against the preserved partial content
    /// without appending a new user message: the prompt is already in the
    /// preserved history, and the partial content of the interrupted stream is
    /// carried forward — folded into the completed reply on completion, or
    /// preserved again on a second interruption (ARC-001, DES-009 §3.3). The
    /// provider and model are selected through the Domain selection service as
    /// in `send`, and the same failure surfaces — `CapabilityError`,
    /// `CredentialStorageError`, `RepositoryError`, never wrapped (§3.6, DES-009
    /// §3.9).
    public func resume(
        _ conversation: ConversationIdentity
    ) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        let prepared = try await prepareResume(conversation)
        return makeStream(
            initialConversation: prepared.conversation,
            selection: prepared.selection,
            resolvedAttachments: prepared.attachments
        )
    }

    /// Performs a send in the caller's task, delivering each update only after
    /// the Domain aggregate has applied it. Cancellation does not return until
    /// the interrupted partial response has been persisted.
    public func performSend(
        _ request: SendMessageRequest,
        onAccepted: @escaping @Sendable () async -> Void = {},
        onUpdate: @escaping @Sendable (StreamingUpdate) async -> Void
    ) async throws {
        let prepared = try await prepareSend(request)
        await onAccepted()
        try await consume(
            initialConversation: prepared.conversation,
            selection: prepared.selection,
            resolvedAttachments: prepared.attachments,
            onUpdate: onUpdate
        )
    }

    /// Performs a resume in the caller's task with the same cancellation and
    /// persistence ordering guarantees as `performSend`.
    public func performResume(
        _ conversation: ConversationIdentity,
        onUpdate: @escaping @Sendable (StreamingUpdate) async -> Void
    ) async throws {
        let prepared = try await prepareResume(conversation)
        try await consume(
            initialConversation: prepared.conversation,
            selection: prepared.selection,
            resolvedAttachments: prepared.attachments,
            onUpdate: onUpdate
        )
    }

    private func prepareSend(
        _ request: SendMessageRequest
    ) async throws -> (
        conversation: Conversation,
        selection: ProviderModelSelection,
        attachments: [ResolvedAttachment]
    ) {
        try validate(request)
        guard var conversation = try await conversationRepository.conversation(with: request.conversation) else {
            throw ApplicationValidationError.invalid(reason: "The conversation is not stored.")
        }
        let selection = await selectionService.select(
            requiredCapability: .streaming,
            explicitSelection: request.modelSelection ?? conversation.modelSelection,
            userSelection: request.userSelection,
            workspacePreference: request.workspacePreference,
            capabilityPreference: request.capabilityPreference
        )
        let resolved: ProviderModelSelection
        switch selection {
        case .selected(let provider, let model):
            resolved = ProviderModelSelection(provider: provider, model: model)
        case .modelUnavailable(let unavailable):
            throw CapabilityError.modelUnavailable(model: unavailable.model)
        case .failure:
            throw CapabilityError.providerUnavailable
        }
        // Resolve the exact route before mutating history. If a saved model has
        // disappeared, the user can choose a replacement and retry without a
        // previously persisted copy of the same draft becoming a duplicate.
        try conversation.append(request.message, at: now())
        let attachments = try await resolveAttachments(conversation.history, resolved)
        try await conversationRepository.save(conversation)
        try conversation.beginStreaming()
        return (conversation, resolved, attachments)
    }

    private func prepareResume(
        _ identity: ConversationIdentity
    ) async throws -> (
        conversation: Conversation,
        selection: ProviderModelSelection,
        attachments: [ResolvedAttachment]
    ) {
        guard var conversation = try await conversationRepository.conversation(with: identity) else {
            throw ApplicationValidationError.invalid(reason: "The conversation is not stored.")
        }
        guard case .interrupted = conversation.streamingState else {
            throw ApplicationValidationError.invalid(
                reason: "The conversation has no interrupted response to resume."
            )
        }
        let selection = await selectionService.select(
            requiredCapability: .streaming,
            explicitSelection: conversation.modelSelection
        )
        let resolved: ProviderModelSelection
        switch selection {
        case .selected(let provider, let model):
            resolved = ProviderModelSelection(provider: provider, model: model)
        case .modelUnavailable(let unavailable):
            throw CapabilityError.modelUnavailable(model: unavailable.model)
        case .failure:
            throw CapabilityError.providerUnavailable
        }
        let attachments = try await resolveAttachments(conversation.history, resolved)
        try conversation.beginStreaming()
        return (conversation, resolved, attachments)
    }

    /// Validates the request at the application boundary (ARC-009, DES-011 §3.6).
    private func validate(_ request: SendMessageRequest) throws {
        guard !request.message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !request.message.attachments.isEmpty
        else {
            throw ApplicationValidationError.invalid(reason: "The user message is empty.")
        }
    }

    /// Builds the stream that consumes the capability stream, forwards its
    /// events, and persists the terminal aggregate state (DES-011 §3.3).
    private func makeStream(
        initialConversation: Conversation,
        selection: ProviderModelSelection,
        resolvedAttachments: [ResolvedAttachment]
    ) -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await consume(
                        initialConversation: initialConversation,
                        selection: selection,
                        resolvedAttachments: resolvedAttachments
                    ) { update in
                        continuation.yield(update)
                    }
                    continuation.finish()
                } catch {
                    guard !Task.isCancelled else { return }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Consumes provider updates in the current task. Terminal persistence is
    /// completed before the update is delivered, while cancellation persists
    /// an interruption before returning to the caller.
    private func consume(
        initialConversation: Conversation,
        selection: ProviderModelSelection,
        resolvedAttachments: [ResolvedAttachment],
        onUpdate: @escaping @Sendable (StreamingUpdate) async -> Void
    ) async throws {
        var conversation = initialConversation
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: conversation.history,
            model: selection.model,
            provider: selection.provider,
            resolvedAttachments: resolvedAttachments
        )
        do {
            let capabilityStream = try await streamingContract.stream(request)
            for try await update in capabilityStream {
                try Task.checkCancellation()
                try await apply(update, to: &conversation)
                switch update {
                case .completion, .interruption:
                    await onUpdate(update)
                    return
                case .contentDelta:
                    try Task.checkCancellation()
                    await onUpdate(update)
                }
            }
            try Task.checkCancellation()
            let partial = conversation.partialContent ?? ""
            throw CapabilityError.streamingInterrupted(partialContent: partial)
        } catch is CancellationError {
            try? await interruptAndPersist(&conversation)
            await onUpdate(
                .interruption(
                    identity: request.identity,
                    partialContent: conversation.partialContent ?? ""
                )
            )
            throw CancellationError()
        } catch {
            try? await preserveForFailure(&conversation, error: error)
            throw error
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
            try conversation.completeStreaming(at: now())
            try await savePreservingMetadata(&conversation)
        case .interruption(_, let partialContent):
            try reconcilePartial(&conversation, to: partialContent)
            try conversation.interruptStreaming(at: now())
            try await savePreservingMetadata(&conversation)
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
        try conversation.interruptStreaming(at: now())
        try await savePreservingMetadata(&conversation)
    }

    /// A generation runs from an isolated aggregate snapshot. Preserve a user
    /// rename that was saved while that generation was in flight before the
    /// terminal streaming snapshot is committed.
    private func savePreservingMetadata(_ conversation: inout Conversation) async throws {
        if let latest = try await conversationRepository.conversation(with: conversation.identity) {
            conversation.mergeMetadata(from: latest)
        }
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
