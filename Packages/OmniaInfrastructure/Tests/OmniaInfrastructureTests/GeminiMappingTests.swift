import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class GeminiMappingTests: XCTestCase {

    // MARK: - Fixtures

    private var identity: CapabilityRequestIdentity {
        CapabilityRequestIdentity()
    }

    private var model: ModelReference {
        ModelReference(name: "gemini-2.5-flash")
    }

    private var history: [Message] {
        [
            Message(role: .system, content: "You are concise."),
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi!"),
        ]
    }

    private func imageAttachment(mediaType: String = "image/png") -> ResolvedAttachment {
        let attachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "photo.png",
            mediaType: mediaType,
            kind: .image,
            byteCount: 4,
            storageKey: "gemini-image-key"
        )
        return ResolvedAttachment(
            attachment: attachment,
            payload: .image(data: Data("abcd".utf8), mediaType: mediaType)
        )
    }

    private func textAttachment() -> ResolvedAttachment {
        let attachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "note.pdf",
            mediaType: "application/pdf",
            kind: .pdf,
            byteCount: 13,
            storageKey: "gemini-text-key"
        )
        return ResolvedAttachment(attachment: attachment, payload: .extractedText("document text"))
    }

    // MARK: - Domain requests to wire requests

    func testTextGenerationRequest_MapsPromptToASingleUserContent() {
        let wire = GeminiMapping.request(
            from: TextGenerationRequest(identity: identity, prompt: "Write a haiku", model: model)
        )

        XCTAssertEqual(
            wire.contents,
            [GeminiContent(role: "user", parts: [GeminiPart(text: "Write a haiku")])]
        )
        XCTAssertNil(wire.systemInstruction)
    }

    func testConversationRequest_MapsSystemToSystemInstructionAndRolesInOrder() throws {
        let wire = try GeminiMapping.request(
            from: ConversationRequest(identity: identity, history: history, model: model)
        )

        XCTAssertEqual(
            wire.contents,
            [
                GeminiContent(role: "user", parts: [GeminiPart(text: "Hello")]),
                GeminiContent(role: "model", parts: [GeminiPart(text: "Hi!")]),
            ]
        )
        XCTAssertEqual(
            wire.systemInstruction,
            GeminiSystemInstruction(parts: [GeminiPart(text: "You are concise.")])
        )
    }

    func testStreamingRequest_MapsHistoryTheSameAsConversation() throws {
        let wire = try GeminiMapping.request(
            from: StreamingRequest(identity: identity, history: history, model: model)
        )

        XCTAssertEqual(wire.contents.count, 2)
        XCTAssertEqual(wire.contents[0], GeminiContent(role: "user", parts: [GeminiPart(text: "Hello")]))
        XCTAssertEqual(
            wire.systemInstruction,
            GeminiSystemInstruction(parts: [GeminiPart(text: "You are concise.")])
        )
    }

    func testConversationRequest_WithNoSystemMessagesRecordsNoSystemInstruction() throws {
        let wire = try GeminiMapping.request(
            from: ConversationRequest(
                identity: identity,
                history: [Message(role: .user, content: "Hello")],
                model: model
            )
        )

        XCTAssertNil(wire.systemInstruction)
    }

    // MARK: - Attachments

    func testConversationRequest_MapsAnImageAttachmentToInlineData() throws {
        let attachment = imageAttachment()
        let message = Message(role: .user, content: "Look", attachments: [attachment.attachment])
        let wire = try GeminiMapping.request(
            from: ConversationRequest(
                identity: identity,
                history: [message],
                model: model,
                resolvedAttachments: [attachment]
            )
        )

        XCTAssertEqual(
            wire.contents,
            [
                GeminiContent(
                    role: "user",
                    parts: [
                        GeminiPart(text: "Look"),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/png",
                                data: Data("abcd".utf8).base64EncodedString()
                            )
                        ),
                    ]
                ),
            ]
        )
    }

    func testConversationRequest_MapsExtractedTextToATextPartWithAttachmentContext() throws {
        let attachment = textAttachment()
        let message = Message(role: .user, content: "Read this", attachments: [attachment.attachment])
        let wire = try GeminiMapping.request(
            from: ConversationRequest(
                identity: identity,
                history: [message],
                model: model,
                resolvedAttachments: [attachment]
            )
        )

        XCTAssertEqual(
            wire.contents,
            [
                GeminiContent(
                    role: "user",
                    parts: [
                        GeminiPart(text: "Read this"),
                        GeminiPart(text: "[Attachment: note.pdf (application/pdf)]\ndocument text"),
                    ]
                ),
            ]
        )
    }

    func testConversationRequest_UnresolvedAttachmentIsAnInvalidRequest() throws {
        let attachment = imageAttachment()
        let message = Message(role: .user, content: "Look", attachments: [attachment.attachment])

        XCTAssertThrowsError(
            try GeminiMapping.request(
                from: ConversationRequest(
                    identity: identity,
                    history: [message],
                    model: model,
                    resolvedAttachments: []
                )
            )
        ) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidRequest)
        }
    }

    func testConversationRequest_NonImageMediaTypeIsAnInvalidRequest() throws {
        let attachment = imageAttachment(mediaType: "application/pdf")
        let message = Message(role: .user, content: "Look", attachments: [attachment.attachment])

        XCTAssertThrowsError(
            try GeminiMapping.request(
                from: ConversationRequest(
                    identity: identity,
                    history: [message],
                    model: model,
                    resolvedAttachments: [attachment]
                )
            )
        ) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidRequest)
        }
    }

    // MARK: - Wire responses to Domain responses

    private func candidateResponse(text: String) -> GenerateContentResponse {
        GenerateContentResponse(
            candidates: [
                GeminiCandidate(
                    index: 0,
                    content: GeminiResponseContent(parts: [GeminiPart(text: text)], role: "model"),
                    finishReason: "STOP"
                ),
            ],
            usageMetadata: nil
        )
    }

    func testTextResponse_UsesTheFirstCandidateText() throws {
        let response = try GeminiMapping.textResponse(from: candidateResponse(text: "First!"))

        XCTAssertEqual(response.text, "First!")
    }

    func testConversationResponse_UsesTheFirstCandidateText() throws {
        let response = try GeminiMapping.conversationResponse(from: candidateResponse(text: "Hi!"))

        XCTAssertEqual(response.message, Message(role: .assistant, content: "Hi!"))
    }

    func testTextResponse_RejectsAResponseWithoutCandidates() {
        let wire = GenerateContentResponse(candidates: [], usageMetadata: nil)

        XCTAssertThrowsError(try GeminiMapping.textResponse(from: wire)) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidResponse)
        }
    }

    func testTextResponse_RejectsAResponseWithNoText() {
        let wire = GenerateContentResponse(
            candidates: [
                GeminiCandidate(
                    index: 0,
                    content: GeminiResponseContent(parts: nil, role: "model"),
                    finishReason: "STOP"
                ),
            ],
            usageMetadata: nil
        )

        XCTAssertThrowsError(try GeminiMapping.textResponse(from: wire)) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidResponse)
        }
    }

    // MARK: - Wire events to Domain streaming updates

    func testEventUpdate_MapsTextToAContentDeltaCarryingTheRequestIdentity() throws {
        let identity = self.identity
        let update = try XCTUnwrap(
            GeminiMapping.update(from: candidateResponse(text: "Hello"), identity: identity)
        )

        XCTAssertEqual(update, .contentDelta(identity: identity, content: "Hello"))
    }

    func testEventUpdate_ProducesNoContentDeltaForAnEmptyEvent() {
        let event = GenerateContentResponse(candidates: [], usageMetadata: nil)

        XCTAssertNil(GeminiMapping.update(from: event, identity: identity))
    }

    func testStreamCompletionMessage_AssemblesTheAssistantMessage() {
        XCTAssertEqual(
            GeminiMapping.streamCompletionMessage(from: "Hello world"),
            Message(role: .assistant, content: "Hello world")
        )
    }

    // MARK: - Error translation

    func testErrorTranslation_UsesTheFrozenTransportRule() {
        XCTAssertEqual(GeminiMapping.capabilityError(from: .httpStatus(401)), .unauthorized)
        XCTAssertEqual(GeminiMapping.capabilityError(from: .httpStatus(429)), .rateLimited)
        XCTAssertEqual(GeminiMapping.capabilityError(from: .networkFailure), .networkUnavailable)
        XCTAssertEqual(GeminiMapping.capabilityError(from: .invalidResponse), .invalidResponse)
    }
}
