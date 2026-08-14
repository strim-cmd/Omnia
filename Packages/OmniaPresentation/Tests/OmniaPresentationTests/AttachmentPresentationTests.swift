import Foundation
import OmniaApplication
import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

private actor AttachmentPresentationRepository: ConversationRepository {
    private var conversations: [ConversationIdentity: Conversation] = [:]

    func save(_ conversation: Conversation) async throws {
        conversations[conversation.identity] = conversation
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        conversations[identity]
    }

    func delete(_ identity: ConversationIdentity) async throws {
        conversations[identity] = nil
    }
}

private struct AttachmentUnusedStreamingContract: StreamingContract {
    func stream(
        _ request: StreamingRequest
    ) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        XCTFail("stream must not start after attachment preflight failure")
        return AsyncThrowingStream { $0.finish() }
    }
}

private struct AttachmentFailingStreamingContract: StreamingContract {
    func stream(
        _ request: StreamingRequest
    ) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        throw CapabilityError.providerUnavailable
    }
}

private actor AttachmentPresentationStateRecorder {
    private var values: [ConversationScreenState] = []
    func append(_ value: ConversationScreenState) { values.append(value) }
    func last() -> ConversationScreenState? { values.last }
}

final class AttachmentPresentationTests: XCTestCase {
    func testMessageAndStateExposeMetadataAndCopyHelpersPreserveStaging() {
        let attachment = makeAttachment()
        let presentation = MessagePresentation(
            message: Message(
                role: .user,
                content: "",
                attachments: [attachment]
            )
        )
        let state = ConversationScreenState(
            messages: [presentation],
            draft: "draft",
            draftAttachments: [attachment],
            attachmentIssue: .capabilityUnknown(.image)
        )

        XCTAssertNil(presentation.content)
        XCTAssertEqual(presentation.attachments, [attachment])
        XCTAssertEqual(state.replacingDraft("edited").draftAttachments, [attachment])
        XCTAssertEqual(
            state.replacingProviderSelection(nil).attachmentIssue,
            .capabilityUnknown(.image)
        )
        XCTAssertEqual(
            state.replacingStreamingCondition(.thinking).draftAttachments,
            [attachment]
        )
    }

    func testSurfacePreflightFailureRestoresFallbackHistoryDraftAndAttachments() async throws {
        let repository = AttachmentPresentationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let provider = ProviderIdentity()
        let lifecycle = ProviderLifecycleService()
        await lifecycle.register(
            ProviderConnection(
                identity: provider,
                capabilities: ProviderCapabilities(capabilities: [.streaming]),
                metadata: ProviderMetadata(displayName: "Provider"),
                limits: ProviderLimits(maxRequestsPerMinute: 60),
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        )
        try await lifecycle.transition(provider, to: .validated)
        try await lifecycle.transition(provider, to: .initializing)
        try await lifecycle.transition(provider, to: .ready)
        let selection = ProviderModelSelection(
            provider: provider,
            model: ModelReference(name: "model")
        )
        let useCase = SendMessageUseCase(
            streamingContract: AttachmentUnusedStreamingContract(),
            selectionService: ProviderSelectionService(
                lifecycleService: lifecycle,
                preferredModels: { _ in [selection.model] }
            ),
            conversationRepository: repository,
            resolveAttachments: { _, _ in
                throw AttachmentError.capabilityUnknown(.image)
            }
        )
        let surface = ConversationScreenSurface(useCase: useCase)
        let attachment = makeAttachment()
        let message = Message(
            role: .user,
            content: "draft",
            attachments: [attachment]
        )
        let base = [MessagePresentation(role: .assistant, content: MarkdownContent(markdown: "Earlier"))]
        let proposed = base + [MessagePresentation(message: message)]
        let recorder = AttachmentPresentationStateRecorder()

        try await surface.performSend(
            SendMessageRequest(
                conversation: conversation.identity,
                message: message,
                modelSelection: selection
            ),
            rendering: proposed,
            fallbackHistory: base,
            preservingDraft: "draft",
            draftAttachments: [attachment],
            onState: { await recorder.append($0) }
        )

        let recordedState = await recorder.last()
        let state = try XCTUnwrap(recordedState)
        XCTAssertEqual(state.messages, base)
        XCTAssertEqual(state.draft, "draft")
        XCTAssertEqual(state.draftAttachments, [attachment])
        XCTAssertEqual(state.attachmentIssue, .capabilityUnknown(.image))
        XCTAssertEqual(state.failure, .attachment(.capabilityUnknown(.image)))
        let stored = try await repository.conversation(with: conversation.identity)
        XCTAssertEqual(stored?.history, [])
    }

    func testPostAcceptanceFailureIsInterruptedSoRetryCannotDuplicateAttachment() async throws {
        let repository = AttachmentPresentationRepository()
        let conversation = Conversation(identity: ConversationIdentity())
        try await repository.save(conversation)
        let provider = ProviderIdentity()
        let lifecycle = ProviderLifecycleService()
        await lifecycle.register(
            ProviderConnection(
                identity: provider,
                capabilities: ProviderCapabilities(capabilities: [.streaming]),
                metadata: ProviderMetadata(displayName: "Provider"),
                limits: ProviderLimits(maxRequestsPerMinute: 60),
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        )
        try await lifecycle.transition(provider, to: .validated)
        try await lifecycle.transition(provider, to: .initializing)
        try await lifecycle.transition(provider, to: .ready)
        let selection = ProviderModelSelection(
            provider: provider,
            model: ModelReference(name: "model")
        )
        let attachment = makeAttachment()
        let resolved = ResolvedAttachment(
            attachment: attachment,
            payload: .image(data: Data([1]), mediaType: "image/png")
        )
        let surface = ConversationScreenSurface(
            useCase: SendMessageUseCase(
                streamingContract: AttachmentFailingStreamingContract(),
                selectionService: ProviderSelectionService(
                    lifecycleService: lifecycle,
                    preferredModels: { _ in [selection.model] }
                ),
                conversationRepository: repository,
                resolveAttachments: { _, _ in [resolved] }
            )
        )
        let message = Message(
            role: .user,
            content: "draft",
            attachments: [attachment]
        )
        let history = [MessagePresentation(message: message)]
        let recorder = AttachmentPresentationStateRecorder()

        try await surface.performSend(
            SendMessageRequest(
                conversation: conversation.identity,
                message: message,
                modelSelection: selection
            ),
            rendering: history,
            fallbackHistory: [],
            preservingDraft: "draft",
            draftAttachments: [attachment],
            onState: { await recorder.append($0) }
        )

        let recorded = await recorder.last()
        let state = try XCTUnwrap(recorded)
        XCTAssertEqual(
            state.streamingCondition,
            .interrupted(partialContent: "")
        )
        XCTAssertEqual(state.draft, "")
        XCTAssertEqual(state.draftAttachments, [])
        let stored = try await repository.conversation(with: conversation.identity)
        XCTAssertEqual(stored?.history, [message])
        XCTAssertEqual(
            stored?.streamingState,
            .interrupted(partialContent: "")
        )
    }

    private func makeAttachment() -> MessageAttachment {
        MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "photo.png",
            mediaType: "image/png",
            kind: .image,
            byteCount: 1,
            storageKey: "opaque.png"
        )
    }
}
