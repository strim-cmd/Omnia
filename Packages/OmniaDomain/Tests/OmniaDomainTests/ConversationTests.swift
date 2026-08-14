import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalConversation = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private func makeIdentity() throws -> ConversationIdentity {
    try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
}

final class ConversationTests: XCTestCase {

    // MARK: Creation

    func testCreation_IsEmptyAndIdle() throws {
        let conversation = Conversation(identity: try makeIdentity())
        XCTAssertTrue(conversation.history.isEmpty)
        XCTAssertEqual(conversation.streamingState, .idle)
        XCTAssertFalse(conversation.isStreaming)
        XCTAssertNil(conversation.partialContent)
        XCTAssertNil(conversation.modelSelection)
    }

    func testModelSelection_IsStoredAndCanBeExplicitlyReplaced() throws {
        let first = ProviderModelSelection(
            provider: ProviderIdentity(),
            model: ModelReference(name: "model-a")
        )
        let second = ProviderModelSelection(
            provider: ProviderIdentity(),
            model: ModelReference(name: "model-b")
        )
        var conversation = Conversation(
            identity: try makeIdentity(),
            modelSelection: first
        )

        try conversation.selectModel(second)

        XCTAssertEqual(conversation.modelSelection, second)
    }

    func testModelSelection_CannotChangeWhileStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()

        XCTAssertThrowsError(
            try conversation.selectModel(
                ProviderModelSelection(
                    provider: ProviderIdentity(),
                    model: ModelReference(name: "late")
                )
            )
        ) { error in
            XCTAssertEqual(error as? ConversationStreamError, .streamInProgress)
        }
        XCTAssertNil(conversation.modelSelection)
    }

    // MARK: History

    func testAppend_AddsToHistory() throws {
        var conversation = Conversation(identity: try makeIdentity())
        let message = Message(role: .user, content: "Hello")
        try conversation.append(message)
        XCTAssertEqual(conversation.history, [message])
    }

    func testAppend_PreservesFullHistory() throws {
        var conversation = Conversation(identity: try makeIdentity())
        let first = Message(role: .user, content: "One")
        let second = Message(role: .assistant, content: "Two")
        try conversation.append(first)
        try conversation.append(second)
        XCTAssertEqual(conversation.history, [first, second])
    }

    func testAppend_RejectedWhileStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        XCTAssertThrowsError(try conversation.append(Message(role: .user, content: "Late"))) { error in
            XCTAssertEqual(error as? ConversationStreamError, .streamInProgress)
        }
    }

    func testFirstUserMessageCreatesNormalizedAutomaticTitleOnce() throws {
        var conversation = Conversation(identity: try makeIdentity())

        try conversation.append(Message(role: .user, content: "  First\n  prompt  "))
        try conversation.append(Message(role: .user, content: "Second prompt"))

        XCTAssertEqual(conversation.title, "First prompt")
        XCTAssertEqual(conversation.titleOrigin, .automatic)
    }

    func testAttachmentOnlyUserMessageCreatesSafeAutomaticTitle() throws {
        let attachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "report.pdf",
            mediaType: "application/pdf",
            kind: .pdf,
            byteCount: 42,
            storageKey: "attachments/report.pdf"
        )
        var conversation = Conversation(identity: try makeIdentity())

        try conversation.append(Message(role: .user, content: "", attachments: [attachment]))

        XCTAssertEqual(conversation.title, "report.pdf")
    }

    func testRenameNormalizesTruncatesAndTakesPrecedence() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.append(Message(role: .user, content: "Automatic"))

        try conversation.rename(to: "  My\n" + String(repeating: "x", count: 200))
        try conversation.append(Message(role: .user, content: "Never replace"))

        XCTAssertEqual(conversation.titleOrigin, .user)
        XCTAssertEqual(conversation.title?.count, 160)
        XCTAssertTrue(conversation.title?.hasPrefix("My x") == true)
    }

    func testRenameRejectsWhitespaceWithoutChangingMetadata() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.append(Message(role: .user, content: "Automatic"))

        XCTAssertThrowsError(try conversation.rename(to: " \n ")) { error in
            XCTAssertEqual(error as? ConversationMetadataError, .invalidTitle)
        }
        XCTAssertEqual(conversation.title, "Automatic")
        XCTAssertEqual(conversation.titleOrigin, .automatic)
    }

    func testActivityDateIsMonotonic() throws {
        let created = Date(timeIntervalSince1970: 200)
        var conversation = Conversation(
            identity: try makeIdentity(),
            createdAt: created,
            updatedAt: created
        )

        try conversation.append(
            Message(role: .user, content: "Hello"),
            at: Date(timeIntervalSince1970: 100)
        )
        try conversation.rename(to: "Renamed", at: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(conversation.updatedAt, Date(timeIntervalSince1970: 300))
    }

    func testMergeMetadataPreservesConcurrentUserRename() throws {
        let created = Date(timeIntervalSince1970: 100)
        var generation = Conversation(
            identity: try makeIdentity(),
            createdAt: created,
            updatedAt: created
        )
        try generation.append(Message(role: .user, content: "Automatic"), at: created)
        var latest = generation
        try latest.rename(to: "User title", at: Date(timeIntervalSince1970: 200))

        generation.mergeMetadata(from: latest)

        XCTAssertEqual(generation.title, "User title")
        XCTAssertEqual(generation.titleOrigin, .user)
        XCTAssertEqual(generation.updatedAt, Date(timeIntervalSince1970: 200))
    }

    // MARK: Streaming

    func testBeginStreaming_FromIdleStartsEmptyStream() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        XCTAssertTrue(conversation.isStreaming)
        XCTAssertEqual(conversation.partialContent, "")
    }

    func testBeginStreaming_RejectedWhileAlreadyStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        XCTAssertThrowsError(try conversation.beginStreaming()) { error in
            XCTAssertEqual(error as? ConversationStreamError, .streamInProgress)
        }
    }

    func testAppendPartial_AccumulatesContent() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("Hel")
        try conversation.appendPartial("lo")
        XCTAssertEqual(conversation.partialContent, "Hello")
        XCTAssertEqual(conversation.streamingState, .streaming(partialContent: "Hello"))
    }

    func testAppendPartial_RejectedWhenNotStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        XCTAssertThrowsError(try conversation.appendPartial("Hello")) { error in
            XCTAssertEqual(error as? ConversationStreamError, .notStreaming)
        }
    }

    func testCompleteStreaming_AddsAssistantMessageAndEndsStream() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("Hello")
        try conversation.completeStreaming()

        XCTAssertEqual(conversation.history, [Message(role: .assistant, content: "Hello")])
        XCTAssertEqual(conversation.streamingState, .idle)
        XCTAssertFalse(conversation.isStreaming)
        XCTAssertNil(conversation.partialContent)
    }

    func testCompleteStreaming_RejectedWhenNotStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        XCTAssertThrowsError(try conversation.completeStreaming()) { error in
            XCTAssertEqual(error as? ConversationStreamError, .notStreaming)
        }
    }

    func testInterruptStreaming_PreservesPartialContentAndMarksIncomplete() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("Hello")
        try conversation.interruptStreaming()

        XCTAssertEqual(conversation.streamingState, .interrupted(partialContent: "Hello"))
        XCTAssertEqual(conversation.partialContent, "Hello")
        XCTAssertFalse(conversation.isStreaming)
    }

    func testInterruptStreaming_NeverDiscardsTheHistory() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.append(Message(role: .user, content: "Question"))
        try conversation.beginStreaming()
        try conversation.appendPartial("Partial")
        try conversation.interruptStreaming()

        XCTAssertEqual(conversation.history, [Message(role: .user, content: "Question")])
        XCTAssertEqual(conversation.streamingState, .interrupted(partialContent: "Partial"))
    }

    func testInterruptStreaming_RejectedWhenNotStreaming() throws {
        var conversation = Conversation(identity: try makeIdentity())
        XCTAssertThrowsError(try conversation.interruptStreaming()) { error in
            XCTAssertEqual(error as? ConversationStreamError, .notStreaming)
        }
    }

    func testStreaming_IsResumableFromInterrupted() throws {
        var conversation = Conversation(identity: try makeIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("Hello")
        try conversation.interruptStreaming()

        try conversation.beginStreaming()
        try conversation.appendPartial(" there")
        try conversation.completeStreaming()

        XCTAssertEqual(conversation.history, [Message(role: .assistant, content: "Hello there")])
    }

    // MARK: Equality

    func testEquality_ContentEqualIsEqual() throws {
        let identity = try makeIdentity()
        var a = Conversation(identity: identity)
        var b = Conversation(identity: identity)
        try a.append(Message(role: .user, content: "Hi"))
        try b.append(Message(role: .user, content: "Hi"))
        XCTAssertEqual(a, b)
    }

    func testEquality_StreamingStateAffectsEquality() throws {
        let identity = try makeIdentity()
        var a = Conversation(identity: identity)
        var b = Conversation(identity: identity)
        try a.beginStreaming()
        try b.beginStreaming()
        try a.appendPartial("Hel")
        try b.appendPartial("Hel")
        XCTAssertEqual(a, b)

        try a.appendPartial("lo")
        XCTAssertNotEqual(a, b)
    }
}
