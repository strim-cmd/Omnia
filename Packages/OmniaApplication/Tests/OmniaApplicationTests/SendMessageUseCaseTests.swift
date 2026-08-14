import Foundation
import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaApplication

private let providerA = "00000000-0000-0000-0000-000000000001"
private let providerB = "00000000-0000-0000-0000-000000000002"

private final class InMemoryConversationRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConversationIdentity: Conversation] = [:]
    let saves: AsyncStream<Conversation>
    private let savesContinuation: AsyncStream<Conversation>.Continuation

    init() {
        let pair = AsyncStream<Conversation>.makeStream()
        saves = pair.stream
        savesContinuation = pair.continuation
    }

    func save(_ conversation: Conversation) async throws {
        lock.withLock {
            storage[conversation.identity] = conversation
        }
        savesContinuation.yield(conversation)
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

private final class SaveOnceThenFailRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let succeedsBeforeFailing: Int
    private var storage: [ConversationIdentity: Conversation] = [:]
    private var saves = 0

    init(succeedsBeforeFailing: Int) {
        self.succeedsBeforeFailing = succeedsBeforeFailing
    }

    func save(_ conversation: Conversation) async throws {
        try lock.withLock {
            saves += 1
            if saves <= succeedsBeforeFailing {
                storage[conversation.identity] = conversation
            } else {
                throw RepositoryError.storageUnavailable
            }
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

private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StreamingRequest?

    func set(_ request: StreamingRequest) {
        lock.withLock {
            stored = request
        }
    }

    func get() -> StreamingRequest? {
        lock.withLock {
            stored
        }
    }
}

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

private func completionStream(_ request: StreamingRequest) -> AsyncThrowingStream<StreamingUpdate, Error> {
    AsyncThrowingStream { continuation in
        continuation.yield(
            .completion(identity: request.identity, message: Message(role: .assistant, content: ""))
        )
        continuation.finish()
    }
}

final class SendMessageUseCaseTests: XCTestCase {

    func testSend_AppendsAndPersistsTheUserMessageBeforeTheStreamIsConsumed() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: repository
        )

        _ = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [Message(role: .user, content: "Hi")])
    }

    func testSend_DeliversDeltasAndPersistsTheAssistantMessageOnCompletion() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
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
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }

        XCTAssertEqual(updates.count, 3)
        guard case .contentDelta(_, "He") = updates[0] else {
            return XCTFail("expected a content delta, got \(updates[0])")
        }
        guard case .contentDelta(_, "llo") = updates[1] else {
            return XCTFail("expected a content delta, got \(updates[1])")
        }
        guard case .completion(_, let message) = updates[2] else {
            return XCTFail("expected a completion, got \(updates[2])")
        }
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello")

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [
            Message(role: .user, content: "Hi"),
            Message(role: .assistant, content: "Hello"),
        ])
        XCTAssertEqual(stored.streamingState, .idle)
    }

    func testPerformSend_CompletionIsPersistedBeforeItReturns() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        .completion(
                            identity: request.identity,
                            message: Message(role: .assistant, content: "Complete")
                        )
                    )
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )

        try await useCase.performSend(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        ) { _ in }

        let persisted = try await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(persisted)
        XCTAssertEqual(stored.history, [
            Message(role: .user, content: "Hi"),
            Message(role: .assistant, content: "Complete"),
        ])
        XCTAssertEqual(stored.streamingState, .idle)
    }

    func testPerformSend_CancellationPersistsPartialBeforeTaskFinishes() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let capability = AsyncThrowingStream<StreamingUpdate, Error>.makeStream()
        let requests = AsyncStream<StreamingRequest>.makeStream()
        let delivered = AsyncStream<StreamingUpdate>.makeStream()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                requests.continuation.yield(request)
                return capability.stream
            },
            selectionService: selection,
            repository: repository
        )
        let task = Task {
            try await useCase.performSend(
                SendMessageRequest(
                    conversation: conversation.identity,
                    message: Message(role: .user, content: "Hi")
                )
            ) { update in
                delivered.continuation.yield(update)
            }
        }

        var requestIterator = requests.stream.makeAsyncIterator()
        let requested = await requestIterator.next()
        let request = try XCTUnwrap(requested)
        capability.continuation.yield(
            .contentDelta(identity: request.identity, content: "Partial")
        )
        var deliveredIterator = delivered.stream.makeAsyncIterator()
        let update = await deliveredIterator.next()
        _ = try XCTUnwrap(update)

        task.cancel()
        do {
            try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {
        }

        let terminalUpdate = await deliveredIterator.next()
        guard case .interruption(_, let partialContent) = try XCTUnwrap(terminalUpdate) else {
            return XCTFail("expected a persisted interruption update")
        }
        XCTAssertEqual(partialContent, "Partial")

        let persisted = try await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(persisted)
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Partial"))
    }

    func testSend_BuildsTheRequestFromThePersistedHistoryAndSelectedModel() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )
        for try await _ in stream {}

        let request = try XCTUnwrap(captured.get())
        XCTAssertEqual(request.history, [Message(role: .user, content: "Hi")])
        XCTAssertEqual(request.model, ModelReference(name: "model"))
    }

    func testSend_HonorsTheUserSelectionPreference() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, identities) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model-a")],
            providerB: [ModelReference(name: "model-b")],
        ])
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi"),
                userSelection: identities[providerB]
            )
        )
        for try await _ in stream {}

        XCTAssertEqual(try XCTUnwrap(captured.get()).model, ModelReference(name: "model-b"))
    }

    func testSend_RoutesTheExactProviderAndModelWhenNamesOverlap() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let shared = ModelReference(name: "shared")
        let (selection, identities) = await makeSelectionService(modelsByProvider: [
            providerA: [shared],
            providerB: [shared],
        ])
        let provider = try XCTUnwrap(identities[providerB])
        let exact = ProviderModelSelection(provider: provider, model: shared)
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )

        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi"),
                modelSelection: exact
            )
        )
        for try await _ in stream {}

        let request = try XCTUnwrap(captured.get())
        XCTAssertEqual(request.provider, provider)
        XCTAssertEqual(request.model, shared)
    }

    func testSend_UnavailableExactModelNeverFallsBackToAnotherProvider() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let shared = ModelReference(name: "shared")
        let (selection, identities) = await makeSelectionService(modelsByProvider: [
            providerA: [shared],
            providerB: [ModelReference(name: "other")],
        ])
        let unavailable = ProviderModelSelection(
            provider: try XCTUnwrap(identities[providerB]),
            model: shared
        )
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )

        do {
            _ = try await useCase.send(
                SendMessageRequest(
                    conversation: conversation.identity,
                    message: Message(role: .user, content: "Hi"),
                    modelSelection: unavailable
                )
            )
            XCTFail("Expected modelUnavailable")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .modelUnavailable(model: shared))
        }
        XCTAssertNil(captured.get())
        let stored = try await repository.conversation(with: conversation.identity)
        XCTAssertEqual(stored, conversation)
    }

    func testSend_HonorsTheWorkspacePreferenceOverTheCapabilityPreference() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, identities) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model-a")],
            providerB: [ModelReference(name: "model-b")],
        ])
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi"),
                workspacePreference: identities[providerB],
                capabilityPreference: identities[providerA]
            )
        )
        for try await _ in stream {}

        XCTAssertEqual(try XCTUnwrap(captured.get()).model, ModelReference(name: "model-b"))
    }

    func testSend_PersistsInterruptionPreservingPartialContent() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                    continuation.yield(
                        .interruption(identity: request.identity, partialContent: "Par")
                    )
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }

        XCTAssertEqual(updates.count, 2)
        guard case .interruption(_, "Par") = updates[1] else {
            return XCTFail("expected an interruption, got \(updates[1])")
        }

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [Message(role: .user, content: "Hi")])
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Par"))
    }

    func testSend_SurfacesCapabilityFailureAndPreservesTheReportedPartialContent() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                    continuation.finish(
                        throwing: CapabilityError.streamingInterrupted(partialContent: "Partial")
                    )
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        var updates: [StreamingUpdate] = []
        do {
            for try await update in stream {
                updates.append(update)
            }
            XCTFail("expected the stream to throw")
        } catch {
            XCTAssertEqual(
                error as? CapabilityError,
                CapabilityError.streamingInterrupted(partialContent: "Partial")
            )
        }
        XCTAssertEqual(updates.count, 1)

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Partial"))
    }

    func testSend_SurfacesMidStreamCapabilityFailureAndPreservesTheAccumulatedPartial() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                    continuation.finish(throwing: CapabilityError.providerUnavailable)
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        do {
            for try await _ in stream {}
            XCTFail("expected the stream to throw")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .providerUnavailable)
        }

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Par"))
    }

    func testSend_SurfacesStreamCreationCapabilityFailureAsIs() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ThrowingStreamingContract(error: CapabilityError.providerUnavailable),
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        do {
            for try await _ in stream {}
            XCTFail("expected the stream to throw")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .providerUnavailable)
        }

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [Message(role: .user, content: "Hi")])
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: ""))
    }

    func testSend_SurfacesCredentialResolutionFailureAsIs() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ThrowingStreamingContract(error: CredentialStorageError.storageUnavailable),
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        do {
            for try await _ in stream {}
            XCTFail("expected the stream to throw")
        } catch {
            XCTAssertEqual(error as? CredentialStorageError, .storageUnavailable)
        }

        let storedConversation = try? await repository.conversation(with: conversation.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: ""))
    }

    func testSend_SurfacesRepositoryFailureDuringSetupAsIs() async throws {
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: FailingConversationRepository()
        )

        do {
            _ = try await useCase.send(
                SendMessageRequest(
                    conversation: ConversationIdentity(),
                    message: Message(role: .user, content: "Hi")
                )
            )
            XCTFail("expected a repository failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testSend_SurfacesRepositoryFailureDuringCompletionAsIs() async throws {
        let repository = SaveOnceThenFailRepository(succeedsBeforeFailing: 2)
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        do {
            for try await _ in stream {}
            XCTFail("expected a repository failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testSend_RejectsAnEmptyUserMessage() async throws {
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: InMemoryConversationRepository()
        )

        do {
            _ = try await useCase.send(
                SendMessageRequest(
                    conversation: ConversationIdentity(),
                    message: Message(role: .user, content: "  ")
                )
            )
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(
                error as? ApplicationValidationError,
                .invalid(reason: "The user message is empty.")
            )
        }
    }

    func testSend_RejectsAConversationThatIsNotStored() async throws {
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: InMemoryConversationRepository()
        )

        do {
            _ = try await useCase.send(
                SendMessageRequest(
                    conversation: ConversationIdentity(),
                    message: Message(role: .user, content: "Hi")
                )
            )
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(
                error as? ApplicationValidationError,
                .invalid(reason: "The conversation is not stored.")
            )
        }
    }

    func testSend_OnConsumerStoppingPreservesPartialContentAsInterrupted() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "Par"))
                }
            },
            selectionService: selection,
            repository: repository
        )
        var stream: AsyncThrowingStream<StreamingUpdate, Error>? = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )

        var updates: [StreamingUpdate] = []
        if let stream {
            for try await update in stream {
                updates.append(update)
                break
            }
        }
        XCTAssertEqual(updates.count, 1)

        stream = nil

        var saves = repository.saves.makeAsyncIterator()
        let state = await nextInterruptedState(
            identity: conversation.identity,
            from: &saves
        )
        XCTAssertEqual(state, .interrupted(partialContent: "Par"))
    }

    func testSend_OnResumeCarriesThePreservedPartialContentIntoTheCompletedReply() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "tial"))
                    continuation.yield(
                        .completion(
                            identity: request.identity,
                            message: Message(role: .assistant, content: "tial")
                        )
                    )
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: interrupted.identity,
                message: Message(role: .user, content: "Second")
            )
        )
        for try await _ in stream {}

        let storedConversation = try? await repository.conversation(with: interrupted.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [
            Message(role: .user, content: "First"),
            Message(role: .user, content: "Second"),
            Message(role: .assistant, content: "Partial"),
        ])
        XCTAssertEqual(stored.streamingState, .idle)
    }

    func testSend_OnResumePreservesCarriedAndNewContentWhenInterruptedAgain() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "t"))
                    continuation.yield(.interruption(identity: request.identity, partialContent: "t"))
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: interrupted.identity,
                message: Message(role: .user, content: "Second")
            )
        )
        for try await _ in stream {}

        let storedConversation = try? await repository.conversation(with: interrupted.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [
            Message(role: .user, content: "First"),
            Message(role: .user, content: "Second"),
        ])
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Part"))
    }

    func testResume_CarriesThePreservedPartialContentIntoTheCompletedReplyWithoutAppendingAUserMessage() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "tial"))
                    continuation.yield(
                        .completion(
                            identity: request.identity,
                            message: Message(role: .assistant, content: "tial")
                        )
                    )
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.resume(interrupted.identity)
        for try await _ in stream {}

        let storedConversation = try? await repository.conversation(with: interrupted.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [
            Message(role: .user, content: "First"),
            Message(role: .assistant, content: "Partial"),
        ])
        XCTAssertEqual(stored.streamingState, .idle)
    }

    func testResume_DeliversThePreservedHistoryToTheProviderWithoutDuplicatingThePrompt() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let captured = CapturedRequest()
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                captured.set(request)
                return completionStream(request)
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.resume(interrupted.identity)
        for try await _ in stream {}

        XCTAssertEqual(try XCTUnwrap(captured.get()).history, [
            Message(role: .user, content: "First"),
        ])
    }

    func testResume_PreservesCarriedAndNewContentWhenInterruptedAgain() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { request in
                AsyncThrowingStream { continuation in
                    continuation.yield(.contentDelta(identity: request.identity, content: "t"))
                    continuation.yield(.interruption(identity: request.identity, partialContent: "t"))
                    continuation.finish()
                }
            },
            selectionService: selection,
            repository: repository
        )
        let stream = try await useCase.resume(interrupted.identity)
        for try await _ in stream {}

        let storedConversation = try? await repository.conversation(with: interrupted.identity)
        let stored = try XCTUnwrap(storedConversation)
        XCTAssertEqual(stored.history, [Message(role: .user, content: "First")])
        XCTAssertEqual(stored.streamingState, .interrupted(partialContent: "Part"))
    }

    func testResume_RejectsAConversationThatIsNotStored() async throws {
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: InMemoryConversationRepository()
        )

        do {
            _ = try await useCase.resume(ConversationIdentity())
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(
                error as? ApplicationValidationError,
                .invalid(reason: "The conversation is not stored.")
            )
        }
    }

    func testResume_RejectsAConversationWithoutAnInterruptedResponse() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: repository
        )

        do {
            _ = try await useCase.resume(conversation.identity)
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(
                error as? ApplicationValidationError,
                .invalid(reason: "The conversation has no interrupted response to resume.")
            )
        }
    }

    func testResume_SurfacesProviderSelectionFailureAsUnavailable() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        var interrupted = conversation
        try interrupted.append(Message(role: .user, content: "First"))
        try interrupted.beginStreaming()
        try interrupted.appendPartial("Par")
        try interrupted.interruptStreaming()
        try await repository.save(interrupted)
        let (selection, _) = await makeSelectionService(modelsByProvider: [:])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: repository
        )

        do {
            _ = try await useCase.resume(interrupted.identity)
            XCTFail("expected a selection failure")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .providerUnavailable)
        }
    }

    func testSend_ShareAcrossConcurrencyDomain() async throws {
        let repository = InMemoryConversationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let (selection, _) = await makeSelectionService(modelsByProvider: [
            providerA: [ModelReference(name: "model")],
        ])
        let useCase = makeUseCase(
            contract: ScriptedStreamingContract { completionStream($0) },
            selectionService: selection,
            repository: repository
        )

        let stream = try await useCase.send(
            SendMessageRequest(
                conversation: conversation.identity,
                message: Message(role: .user, content: "Hi")
            )
        )
        let updates = try await Task.detached {
            var collected: [StreamingUpdate] = []
            for try await update in stream {
                collected.append(update)
            }
            return collected
        }.value

        XCTAssertEqual(updates.count, 1)
        guard case .completion = updates[0] else {
            return XCTFail("expected a completion, got \(updates[0])")
        }
    }

    private func nextInterruptedState(
        identity: ConversationIdentity,
        from saves: inout AsyncStream<Conversation>.Iterator
    ) async -> ConversationStreamingState? {
        while let conversation = await saves.next() {
            if conversation.identity == identity,
               case .interrupted = conversation.streamingState {
                return conversation.streamingState
            }
        }
        return nil
    }
}
