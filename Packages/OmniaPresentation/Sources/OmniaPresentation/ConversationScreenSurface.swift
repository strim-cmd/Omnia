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
        AsyncThrowingStream { continuation in
            let task = Task {
                var partialContent = ""
                do {
                    let stream = try await useCase.send(request)
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
                        case .interruption(_, let partialContent):
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
                    continuation.yield(ConversationScreenState(messages: history, failure: failure))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
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
}
