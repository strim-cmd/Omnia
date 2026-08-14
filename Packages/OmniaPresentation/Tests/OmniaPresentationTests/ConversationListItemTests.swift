import Foundation
import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class ConversationListItemTests: XCTestCase {

    private let canonical = "550E8400-E29B-41D4-A716-446655440000"

    private func identity() throws -> ConversationIdentity {
        try XCTUnwrap(ConversationIdentity(restoring: canonical))
    }

    private func conversation(
        history: [Message],
        identity: ConversationIdentity
    ) throws -> Conversation {
        var conversation = Conversation(identity: identity)
        for message in history {
            try conversation.append(message)
        }
        return conversation
    }

    // MARK: Creation

    func testCreation_ExposesIdentityAndDisplayContent() throws {
        let item = ConversationListItem(
            identity: try identity(),
            displayTitle: "A title",
            displayPreview: "A preview"
        )
        XCTAssertEqual(item.identity, try identity())
        XCTAssertEqual(item.displayTitle, "A title")
        XCTAssertEqual(item.displayPreview, "A preview")
    }

    func testCreation_AcceptsNilPreview() throws {
        let item = ConversationListItem(
            identity: try identity(),
            displayTitle: "A title",
            displayPreview: nil
        )
        XCTAssertNil(item.displayPreview)
    }

    // MARK: Derivation from a conversation

    func testDerivation_TitleIsFirstUserMessageAndPreviewIsLastMessage() throws {
        let conversation = try self.conversation(
            history: [
                Message(role: .system, content: "Instructions"),
                Message(role: .user, content: "Hello\nworld"),
                Message(role: .assistant, content: "A reply"),
            ],
            identity: try identity()
        )
        let item = ConversationListItem(conversation: conversation)
        XCTAssertEqual(item.identity, try identity())
        XCTAssertEqual(item.displayTitle, "Hello world")
        XCTAssertEqual(item.displayPreview, "A reply")
    }

    func testDerivation_FallsBackToAssistantMessageWhenNoUserMessage() throws {
        let conversation = try self.conversation(
            history: [Message(role: .assistant, content: "Assistant only")],
            identity: try identity()
        )
        let item = ConversationListItem(conversation: conversation)
        XCTAssertEqual(item.displayTitle, "Assistant only")
    }

    func testDerivation_EmptyConversationHasEmptyTitleAndNilPreview() throws {
        let item = ConversationListItem(
            conversation: Conversation(identity: try identity())
        )
        XCTAssertEqual(item.displayTitle, "")
        XCTAssertNil(item.displayPreview)
    }

    func testDerivation_WhitespaceIsCollapsedToASingleLine() throws {
        let conversation = try self.conversation(
            history: [Message(role: .user, content: "line1\n\nline2\n  line3")],
            identity: try identity()
        )
        let item = ConversationListItem(conversation: conversation)
        XCTAssertEqual(item.displayTitle, "line1 line2 line3")
    }

    func testDerivation_UsesExplicitTitleAndDurableDates() throws {
        let created = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        var conversation = Conversation(
            identity: try identity(),
            createdAt: created,
            updatedAt: created
        )
        try conversation.append(Message(role: .user, content: "Automatic"), at: created)
        try conversation.rename(to: "User title", at: updated)

        let item = ConversationListItem(conversation: conversation)

        XCTAssertEqual(item.displayTitle, "User title")
        XCTAssertEqual(item.createdAt, created)
        XCTAssertEqual(item.updatedAt, updated)
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() throws {
        let a = ConversationListItem(
            identity: try identity(),
            displayTitle: "Title",
            displayPreview: "Preview"
        )
        let b = ConversationListItem(
            identity: try identity(),
            displayTitle: "Title",
            displayPreview: "Preview"
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentContentIsNotEqual() throws {
        let a = ConversationListItem(
            identity: try identity(),
            displayTitle: "Title",
            displayPreview: "Preview"
        )
        let b = ConversationListItem(
            identity: try identity(),
            displayTitle: "Other",
            displayPreview: "Preview"
        )
        XCTAssertNotEqual(a, b)
    }
}
