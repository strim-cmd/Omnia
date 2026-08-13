import OmniaApplication
import OmniaFoundation

/// The conversation screen presentation surface: presents the active
/// conversation's history and renders the streaming send-message flow over
/// `SendMessageUseCase` as `ConversationScreenState` (DES-012 §3.3,
/// Conversation module, ARC-007).
///
/// The surface is the seam through which the frozen `SendMessageUseCase` of
/// DES-011 §3.3 is delivered to the conversation screen (DES-012 §3.6,
/// ARC-006). It receives the use case through its public initializer, presents
/// the conversation it is given (DES-011 §3.2), and renders the Domain
/// `StreamingUpdate` events of the streaming flow incrementally — the content
/// deltas as they arrive without blocking the interface, the assembled
/// assistant message of the completion event, and the preserved partial content
/// of an interruption as incomplete, never discarded (ARC-001, DES-009
/// §3.11.4).
///
/// It consumes only the frozen DES-011 conversation surface and owns no
/// business rules (ARC-002): the `Conversation` aggregate owns the history and
/// streaming-state invariants, and the use case sequences the streaming flow.
/// The surface only translates the events the use case delivers into
/// ready-to-render state and the request it is given into the use case's
/// invocation (ARC-002, ADR-0001). The failures the use case surfaces —
/// `ApplicationValidationError`, and the Domain `RepositoryError`,
/// `CapabilityError`, and `CredentialStorageError` — are presented as they
/// are, never wrapped or redefined (DES-011 §3.6, DES-009 §3.9); no failure is
/// silent (ARC-001). The surface never references a concrete Infrastructure
/// implementation and never performs networking, persistence, or credential
/// operations (ARC-002, ADR-0002).
///
/// The surface is a stateless, `Sendable` value type; every operation is
/// deterministic and testable on the Linux build environment (DES-012 §3.7).
/// Cancellation is cooperative through the returned stream: cancelling the
/// consumer's task propagates to the use case's stream, and the flow stops at
/// its own safe points preserving its partial content (DES-008, ARC-001).
public struct ConversationScreenSurface: Sendable {
    private let useCase: SendMessageUseCase

    /// Creates a conversation screen surface over the given send-message use
    /// case, delivered by the Composition Root (DES-012 §3.6).
    public init(useCase: SendMessageUseCase) {
        self.useCase = useCase
    }

    /// Composes the ready-to-render screen state of `conversation` (DES-012
    /// §3.2): the history as message presentations, and the preserved partial
    /// content of an interrupted stream as an interrupted condition —
    /// incomplete, never discarded (ARC-001).
    ///
    /// The surface presents the conversation it is given; the active
    /// conversation is session state owned at the application edge (DES-011
    /// §3.2).
    public func load(_ conversation: Conversation) -> ConversationScreenState {
        let messages = conversation.history.map { MessagePresentation(message: $0) }
        let streamingCondition: ConversationScreenState.StreamingCondition?
        switch conversation.streamingState {
        case .interrupted(let partialContent):
            streamingCondition = .interrupted(partialContent: partialContent)
        case .idle, .streaming:
            streamingCondition = nil
        }
        return ConversationScreenState(
            messages: messages,
            streamingCondition: streamingCondition
        )
    }

    /// Performs the streaming flow for `request` and renders the Domain
    /// `StreamingUpdate` events incrementally as `ConversationScreenState`
    /// snapshots (DES-012 §3.3, DES-011 §3.3).
    ///
    /// The `history` rendered is the history the screen already presents — the
    /// active conversation's message presentations — so every yielded state
    /// carries the full rendered history alongside the streaming condition:
    /// `active` renders the content deltas incrementally without blocking the
    /// interface, `complete` renders the assembled assistant message of the
    /// completion event appended to the history, and `interrupted` renders the
    /// preserved partial content as incomplete, never discarded (ARC-001,
    /// DES-009 §3.11.4).
    ///
    /// The failures the use case surfaces — `ApplicationValidationError`, and
    /// the Domain `RepositoryError`, `CapabilityError`, and
    /// `CredentialStorageError` — are presented as a typed terminal failure
    /// state, as they are, never wrapped or redefined (DES-011 §3.6, DES-009
    /// §3.9); an unexpected failure is thrown as it is. The flow stops
    /// cooperatively on cancellation, distinct from failure (DES-008, ARC-001).
    public func send(
        _ request: SendMessageRequest,
        rendering history: [MessagePresentation] = []
    ) -> AsyncThrowingStream<ConversationScreenState, any Error> {
        perform({ try await useCase.send(request) }, rendering: history)
    }

    /// Performs a send in the caller's task. This is the session coordinator's
    /// structured-concurrency path: cancellation returns only after the
    /// Application use case has persisted the interrupted partial response.
    public func performSend(
        _ request: SendMessageRequest,
        rendering history: [MessagePresentation] = [],
        onState: @escaping @Sendable (ConversationScreenState) async -> Void
    ) async throws {
        try await performInCurrentTask(
            { onUpdate in
                try await useCase.performSend(request, onUpdate: onUpdate)
            },
            rendering: history,
            onState: onState
        )
    }

    /// Resumes the interrupted response of a conversation and renders the
    /// Domain `StreamingUpdate` events incrementally as `ConversationScreenState`
    /// snapshots (UX audit U7, DES-012 §3.3, DES-011 §3.3).
    ///
    /// Unlike `send`, a resume does not add a user message: the last prompt is
    /// already in the rendered history, and the preserved partial content of
    /// the interrupted stream is carried forward into the reply — the content
    /// deltas accumulate onto `partialContent`, so the active condition renders
    /// the carried content as it continues, the completion event appends the
    /// assembled assistant message, and a second interruption preserves the
    /// carried content again, never discarded (ARC-001, DES-009 §3.3,
    /// §3.11.4). The `history` rendered is the screen's current message
    /// presentations; `partialContent` is the interrupted condition's preserved
    /// content the screen presents.
    ///
    /// The failures the use case surfaces are presented as a typed terminal
    /// failure state, as they are, never wrapped (DES-011 §3.6, DES-009 §3.9);
    /// an unexpected failure is thrown as it is. The flow stops cooperatively
    /// on cancellation, distinct from failure (DES-008, ARC-001).
    public func resume(
        _ conversation: ConversationIdentity,
        from partialContent: String,
        rendering history: [MessagePresentation] = []
    ) -> AsyncThrowingStream<ConversationScreenState, any Error> {
        perform(
            { try await useCase.resume(conversation) },
            rendering: history,
            startingPartial: partialContent
        )
    }

    /// Performs a resume in the caller's task with structured cancellation and
    /// interrupted-response persistence ordering.
    public func performResume(
        _ conversation: ConversationIdentity,
        from partialContent: String,
        rendering history: [MessagePresentation] = [],
        onState: @escaping @Sendable (ConversationScreenState) async -> Void
    ) async throws {
        try await performInCurrentTask(
            { onUpdate in
                try await useCase.performResume(conversation, onUpdate: onUpdate)
            },
            rendering: history,
            startingPartial: partialContent,
            onState: onState
        )
    }

    /// Renders a send-message operation while keeping its whole cancellation
    /// and persistence chain in the coordinator-owned task.
    private func performInCurrentTask(
        _ start: @escaping @Sendable (
            @escaping @Sendable (StreamingUpdate) async -> Void
        ) async throws -> Void,
        rendering history: [MessagePresentation],
        startingPartial: String = "",
        onState: @escaping @Sendable (ConversationScreenState) async -> Void
    ) async throws {
        let renderer = StreamingStateRenderer(
            history: history,
            partialContent: startingPartial
        )
        do {
            try await start { update in
                await onState(renderer.state(for: update))
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let failure = Self.failure(from: error) else {
                throw error
            }
            let reportedPartial: String?
            if case CapabilityError.streamingInterrupted(let content) = error {
                reportedPartial = content
            } else {
                reportedPartial = nil
            }
            await onState(renderer.failureState(failure, reportedPartial: reportedPartial))
        }
    }

    /// Performs the given send-message use-case operation and renders the
    /// Domain `StreamingUpdate` events incrementally as `ConversationScreenState`
    /// snapshots (DES-012 §3.3, DES-011 §3.3).
    ///
    /// The `history` rendered is the history the screen already presents, so
    /// every yielded state carries the full rendered history alongside the
    /// streaming condition: `active` renders the content deltas incrementally
    /// onto `startingPartial` — empty for a send, the preserved content for a
    /// resume — `complete` renders the assembled assistant message of the
    /// completion event appended to the history, and `interrupted` renders the
    /// preserved partial content as incomplete, never discarded (ARC-001,
    /// DES-009 §3.11.4).
    ///
    /// The failures the use case surfaces — `ApplicationValidationError`, and
    /// the Domain `RepositoryError`, `CapabilityError`, and
    /// `CredentialStorageError` — are presented as a typed terminal failure
    /// state, as they are, never wrapped or redefined (DES-011 §3.6, DES-009
    /// §3.9); an unexpected failure is thrown as it is. The flow stops
    /// cooperatively on cancellation, distinct from failure (DES-008, ARC-001).
    private func perform(
        _ start: @escaping @Sendable () async throws -> AsyncThrowingStream<StreamingUpdate, Error>,
        rendering history: [MessagePresentation],
        startingPartial: String = ""
    ) -> AsyncThrowingStream<ConversationScreenState, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var partialContent = startingPartial
                do {
                    let stream = try await start()
                    for try await update in stream {
                        switch update {
                        case .contentDelta(_, let content):
                            partialContent += content
                            continuation.yield(
                                ConversationScreenState(
                                    messages: history,
                                    streamingCondition: .active(partialContent: partialContent)
                                )
                            )
                        case .completion(_, let message):
                            continuation.yield(
                                ConversationScreenState(
                                    messages: history + [MessagePresentation(message: message)],
                                    streamingCondition: .complete
                                )
                            )
                            continuation.finish()
                            return
                        case .interruption(_, let content):
                            // The interruption event reports the partial content
                            // the provider accumulated since the request began;
                            // on a resume the carried content precedes it, so the
                            // preserved partial is the longer of the two when one
                            // extends the other — never discarded (ARC-001,
                            // DES-009 §3.11.4).
                            partialContent = Self.reconciledPartial(current: partialContent, to: content)
                            continuation.yield(
                                ConversationScreenState(
                                    messages: history,
                                    streamingCondition: .interrupted(partialContent: partialContent)
                                )
                            )
                            continuation.finish()
                            return
                        }
                    }
                    // The use case ends its stream with a terminal event or an
                    // error; an unterminated end is the Domain-declared
                    // streaming-interruption failure of DES-009 §3.11.4.
                    guard !Task.isCancelled else { return }
                    continuation.finish(
                        throwing: CapabilityError.streamingInterrupted(partialContent: partialContent)
                    )
                } catch is CancellationError {
                    guard !Task.isCancelled else { return }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    guard !Task.isCancelled else { return }
                    guard let failure = Self.failure(from: error) else {
                        continuation.finish(throwing: error)
                        return
                    }
                    if case CapabilityError.streamingInterrupted(let content) = error {
                        partialContent = Self.reconciledPartial(
                            current: partialContent,
                            to: content
                        )
                    }
                    let condition: ConversationScreenState.StreamingCondition? = partialContent.isEmpty
                        ? nil
                        : .interrupted(partialContent: partialContent)
                    continuation.yield(ConversationScreenState(
                        messages: history,
                        streamingCondition: condition,
                        failure: failure
                    ))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Reconciles the partial content an interruption event reports onto the
    /// partial content already accumulated: when one extends the other it is
    /// carried forward in full, otherwise the accumulated content is kept —
    /// partial content is never discarded (ARC-001, DES-009 §3.11.4).
    private static func reconciledPartial(current: String, to content: String) -> String {
        if content.hasPrefix(current), content.count > current.count {
            return content
        }
        return current
    }

    /// Maps the typed failures of the send-message use case into the screen's
    /// typed failure, as they are, never wrapped (DES-011 §3.6, DES-009 §3.9).
    private static func failure(from error: any Error) -> ConversationScreenState.Failure? {
        switch error {
        case let error as ApplicationValidationError:
            return .application(error)
        case let error as RepositoryError:
            return .repository(error)
        case let error as CapabilityError:
            return .capability(error)
        case let error as CredentialStorageError:
            return .credentialStorage(error)
        default:
            return nil
        }
    }

    /// Serial renderer used by the structured operation callback. The callback
    /// is `@Sendable`, so accumulated partial content is actor-isolated rather
    /// than captured mutable state.
    private actor StreamingStateRenderer {
        let history: [MessagePresentation]
        var partialContent: String

        init(history: [MessagePresentation], partialContent: String) {
            self.history = history
            self.partialContent = partialContent
        }

        func state(for update: StreamingUpdate) -> ConversationScreenState {
            switch update {
            case .contentDelta(_, let content):
                partialContent += content
                return ConversationScreenState(
                    messages: history,
                    streamingCondition: .active(partialContent: partialContent)
                )
            case .completion(_, let message):
                return ConversationScreenState(
                    messages: history + [MessagePresentation(message: message)],
                    streamingCondition: .complete
                )
            case .interruption(_, let content):
                partialContent = ConversationScreenSurface.reconciledPartial(
                    current: partialContent,
                    to: content
                )
                return ConversationScreenState(
                    messages: history,
                    streamingCondition: .interrupted(partialContent: partialContent)
                )
            }
        }

        func failureState(
            _ failure: ConversationScreenState.Failure,
            reportedPartial: String?
        ) -> ConversationScreenState {
            if let reportedPartial {
                partialContent = ConversationScreenSurface.reconciledPartial(
                    current: partialContent,
                    to: reportedPartial
                )
            }
            let condition: ConversationScreenState.StreamingCondition? = partialContent.isEmpty
                ? nil
                : .interrupted(partialContent: partialContent)
            return ConversationScreenState(
                messages: history,
                streamingCondition: condition,
                failure: failure
            )
        }
    }
}
