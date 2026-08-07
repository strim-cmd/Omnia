import Foundation
import OmniaApplication
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

private let providerA = "00000000-0000-0000-0000-000000000001"

private final class InMemoryConversationRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConversationIdentity: Conversation] = [:]

    func save(_ conversation: Conversation) async throws {
        lock.withLock {
            storage[conversation.identity] = conversation
        }
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        lock.withLock {
            storage[identity]
        }
    }

    func delete(_ identity: ConversationIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class FailingConversationRepository: ConversationRepository, @unchecked Sendable {
    func save(_ conversation: Conversation) async throws {
        throw RepositoryError.storageUnavailable
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        throw RepositoryError.storageUnavailable
    }

    func delete(_ identity: ConversationIdentity) async throws {
        throw RepositoryError.storageUnavailable
    }
}

private final class ScriptedStreamingContract: StreamingContract, @unchecked Sendable {
    private let handler: @Sendable (StreamingRequest) -> AsyncThrowingStream<StreamingUpdate, Error>

    init(
        _ handler: @escaping @Sendable (StreamingRequest) -> AsyncThrowingStream<StreamingUpdate, Error>
    ) {
        self.handler = handler
    }

    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        handler(request)
    }
}

private final class ThrowingStreamingContract: StreamingContract, @unchecked Sendable {
    private let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        throw error
    }
}

private struct UnexpectedError: Error {}

private func makeConnection(
    identity: ProviderIdentity,
    capabilities: Set<Capability> = [.streaming]
) -> ProviderConnection {
    ProviderConnection(
        identity: identity,
        capabilities: ProviderCapabilities(capabilities: capabilities),
        metadata: ProviderMetadata(displayName: "Mock Provider"),
        limits: ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion(major: 1, minor: 0, patch: 0)
    )
}

private func makeSelectionService(
    modelsByProvider: [String: [ModelReference]]
) async -> (ProviderSelectionService, [String: ProviderIdentity]) {
    let lifecycle = ProviderLifecycleService()
    var identities: [String: ProviderIdentity] = [:]
    for (canonical, _) in modelsByProvider {
        let identity = try! XCTUnwrap(ProviderIdentity(restoring: canonical))
        identities[canonical] = identity
        await lifecycle.register(makeConnection(identity: identity, capabilities: [.streaming]))
        try! await lifecycle.transition(identity, to: .validated)
        try! await lifecycle.transition(identity, to: .initializing)
        try! await lifecycle.transition(identity, to: .ready)
    }
    let service = ProviderSelectionService(
        lifecycleService: lifecycle,
        preferredModels: { identity in
            modelsByProvider[identity.canonicalString] ?? []
        }
    )
    return (service, identities)
}

private func makeUseCase(
    contract: any StreamingContract,
    selectionService: ProviderSelectionService,
    repository: any ConversationRepository
) -> SendMessageUseCase {
    SendMessageUseCase(
        streamingContract: contract,
        selectionService: selectionService,
        conversationRepository: repository
    )
}

private func makeSurface(
    contract: any StreamingContract,
    repository: any ConversationRepository
) async -> ConversationScreenSurface {
    let (selection, _) = await makeSelectionService(modelsByProvider: [
        providerA: [ModelReference(name: "model")],
    ])
    return ConversationScreenSurface(
        useCase: makeUseCase(
            contract: contract,
            selectionService: selection,
            repository: repository
        )
    )
}

private func presentation(
    role: MessageRole,
    _ content: String
) -> MessagePresentation {
    MessagePresentation(message: Message(role: role, content: content))
}

private func userHistory(_ content: String = "Hi") -> [MessagePresentation] {
    [presentation(role: .user, content)]
}

final class ConversationScreenSurfaceTests: XCTestCase {

    func testLoad_RendersHistoryAndNoStreamingCondition() throws {
        let identity = ConversationIdentity()
        var conversation = Conversation(identity: identity)
        try conversation.append(Message(role: .user, content: "Hello"))
        try conversation.append(Message(role: .assistant, content: "World"))
        let surface = ConversationScreenSurface(useCase: makeUseCase(
            contract: ScriptedStreamingContract { _ in
                AsyncThrowingStream { $0.finish() }
            },
            selectionService: ProviderSelectionService(
                lifecycleService: ProviderLifecycleService(),
                preferredModels: { _ in [] }
            ),
            repository: InMemoryConversationRepository()
        ))

        let state = surface.load(conversation)

        XCTAssertEqual(state.messages, [
            presentation(role: .user, "Hello"),
            presentation(role: .assistant, "World"),
        ])
        XCTAssertNil(state.streamingCondition)
        XCTAssertNil(state.failure)
    }

    func testLoad_RendersInterruptedPartialContentAsIncomplete() throws {
        let identity = ConversationIdentity()
        var conversation = Conversation(identity: identity)
        try conversation.beginStreaming()
        try conversation.appendPartial("Partial")
        try conversation.interruptStreaming()
        let surface = ConversationScreenSurface(useCase: makeUseCase(
            contract: ScriptedStreamingContract { _ in
                AsyncThrowingStream { $0.finish() }
            },
            selectionService: ProviderSelectionService(
                lifecycleService: ProviderLifecycleService(),
                preferredModels: { _ in [] }
            ),
            repository: InMemoryConversationRepository()
        ))

        let state = surface.load(conversation)

        XCTAssertEqual(state.streamingCondition, .interrupted(partialContent: "Partial"))
    }

    func testLoad_EmptyConversationRendersEmptyHistory() {
        let surface = ConversationScreenSurface(useCase: makeUseCase(
            contract: ScriptedStreamingContract { _ in
                AsyncThrowingStream { $0.finish() }
            },
            selectionService: ProviderSelectionService(
                lifecycleService: ProviderLifecycleService(),
                preferredModels: { _ in [] }
            ),
            repository: InMemoryConversationRepository()
        ))

        let state = surface.load(Conversation(identity: ConversationIdentity()))

        XCTAssertEqual(state.messages, [])
        XCTAssertNil(state.streamingCondition)
    }

    func testSend_DeliversDeltasIncrementallyPreservingHistory() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "He"))
                    continuation.yield(.contentDelta(identity: request.identity, content: "llo"))
                    continuation.yield(
                        .completion(
                            identity: request.identity,
                            message: Message(role: .assistant, content: "Hello")
                        )
                    )
                    continuation.finish()
                }
            },
            repository: repository
        )

        var states: [ConversationScreenState] = []
        for try await state in surface.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            ),
            rendering: userHistory()
        ) {
            states.append(state)
        }

        XCTAssertEqual(states.count, 3)
        XCTAssertEqual(states[0].messages, userHistory())
        XCTAssertEqual(states[0].streamingCondition, .active(partialContent: "He"))
        XCTAssertEqual(states[1].messages, userHistory())
        XCTAssertEqual(states[1].streamingCondition, .active(partialContent: "Hello"))
        XCTAssertNil(states[2].failure)
    }

    func testSend_OnCompletionAppendsTheAssembledAssistantMessage() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Hel"))
                    continuation.yield(
                        .completion(
                            identity: request.identity,
                            message: Message(role: .assistant, content: "Hello")
                        )
                    )
                    continuation.finish()
                }
            },
            repository: repository
        )

        var states: [ConversationScreenState] = []
        for try await state in surface.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            ),
            rendering: userHistory()
        ) {
            states.append(state)
        }

        let completed = try XCTUnwrap(states.last)
        XCTAssertEqual(completed.messages, userHistory() + [presentation(role: .assistant, "Hello")])
        XCTAssertEqual(completed.streamingCondition, .complete)
        XCTAssertNil(completed.failure)
    }

    func testSend_OnInterruptionPreservesPartialContentAsIncomplete() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                    continuation.yield(.interruption(identity: request.identity, partialContent: "Par"))
                    continuation.finish()
                }
            },
            repository: repository
        )

        var states: [ConversationScreenState] = []
        for try await state in surface.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            ),
            rendering: userHistory()
        ) {
            states.append(state)
        }

        XCTAssertEqual(states.count, 2)
        let interrupted = try XCTUnwrap(states.last)
        XCTAssertEqual(interrupted.messages, userHistory())
        XCTAssertEqual(interrupted.streamingCondition, .interrupted(partialContent: "Par"))
        XCTAssertNil(interrupted.failure)
    }

    func testSend_PresentsCapabilityFailureAsTerminalState() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                    continuation.finish(
                        throwing: CapabilityError.streamingInterrupted(partialContent: "Partial")
                    )
                }
            },
            repository: repository
        )

        var states: [ConversationScreenState] = []
        do {
            for try await state in surface.send(
                SendMessageRequest(
                    conversation: conversation.identity,
                    message: Message(role: .user, content: "Hi")
                ),
                rendering: userHistory()
            ) {
                states.append(state)
            }
        } catch {
            return XCTFail("expected a terminal failure state, got a throw: \(error)")
        }

        XCTAssertEqual(states.count, 2)
        let failed = try XCTUnwrap(states.last)
        XCTAssertEqual(
            failed.failure,
            .capability(.streamingInterrupted(partialContent: "Partial"))
        )
        XCTAssertTrue(failed.hasError)
    }

    func testSend_PresentsValidationFailureAsTerminalState() async throws {
        let repository = InMemoryConversationRepository()
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { _ in
                AsyncThrowingStream { $0.finish() }
            },
            repository: repository
        )

        var states: [ConversationScreenState] = []
        do {
            for try await state in surface.send(
                SendMessageRequest(
                    conversation: ConversationIdentity(),
                    message: Message(role: .user, content: "  ")
                )
            ) {
                states.append(state)
            }
        } catch {
            return XCTFail("expected a terminal failure state, got a throw: \(error)")
        }

        XCTAssertEqual(states.count, 1)
        let failed = try XCTUnwrap(states.first)
        XCTAssertEqual(
            failed.failure,
            .application(.invalid(reason: "The user message is empty."))
        )
    }

    func testSend_PresentsRepositoryFailureAsTerminalState() async throws {
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { _ in
                AsyncThrowingStream { $0.finish() }
            },
            repository: FailingConversationRepository()
        )

        var states: [ConversationScreenState] = []
        do {
            for try await state in surface.send(
                SendMessageRequest(
                    conversation: ConversationIdentity(),
                    message: Message(role: .user, content: "Hi")
                )
            ) {
                states.append(state)
            }
        } catch {
            return XCTFail("expected a terminal failure state, got a throw: \(error)")
        }

        XCTAssertEqual(states.count, 1)
        let failed = try XCTUnwrap(states.first)
        XCTAssertEqual(failed.failure, .repository(.storageUnavailable))
    }

    func testSend_PresentsCredentialFailureAsTerminalState() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ThrowingStreamingContract(error: CredentialStorageError.storageUnavailable),
            repository: repository
        )

        var states: [ConversationScreenState] = []
        do {
            for try await state in surface.send(
                SendMessageRequest(
                    conversation: conversation.identity,
                    message: Message(role: .user, content: "Hi")
                )
            ) {
                states.append(state)
            }
        } catch {
            return XCTFail("expected a terminal failure state, got a throw: \(error)")
        }

        XCTAssertEqual(states.count, 1)
        let failed = try XCTUnwrap(states.first)
        XCTAssertEqual(failed.failure, .credentialStorage(.storageUnavailable))
    }

    func testSend_PropagatesUnexpectedFailureAsThrow() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ThrowingStreamingContract(error: UnexpectedError()),
            repository: repository
        )

        var states: [ConversationScreenState] = []
        do {
            for try await state in surface.send(
                SendMessageRequest(
                    conversation: conversation.identity,
                    message: Message(role: .user, content: "Hi")
                )
            ) {
                states.append(state)
            }
            XCTFail("expected the stream to throw")
        } catch is UnexpectedError {
        }
        XCTAssertEqual(states.count, 0)
    }

    func testSend_OnConsumerStoppingPreservesPartialContentAsInterrupted() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let surface = await makeSurface(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                }
            },
            repository: repository
        )

        var stream: AsyncThrowingStream<ConversationScreenState, any Error>? = surface.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            ),
            rendering: userHistory()
        )
        var states: [ConversationScreenState] = []
        if let stream {
            for try await state in stream {
                states.append(state)
                break
            }
        }
        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0].streamingCondition, .active(partialContent: "Par"))

        stream = nil

        let state = await pollInterruptedState(identity: conversation.identity, repository: repository)
        XCTAssertEqual(state, .interrupted(partialContent: "Par"))
    }

    private func pollInterruptedState(
        identity: ConversationIdentity,
        repository: InMemoryConversationRepository
    ) async -> ConversationStreamingState? {
        for _ in 0..<200 {
            if let conversation = try? await repository.conversation(with: identity),
               case .interrupted = conversation.streamingState {
                return conversation.streamingState
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return nil
    }
}
