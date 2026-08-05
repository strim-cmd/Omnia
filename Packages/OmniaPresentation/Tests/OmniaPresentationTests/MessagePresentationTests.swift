import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class MessagePresentationTests: XCTestCase {

    // MARK: Creation

    func testCreation_ExposesRoleAndContent() {
        let content = MarkdownContent(segments: [.text("Hello")])
        let presentation = MessagePresentation(role: .user, content: content)
        XCTAssertEqual(presentation.role, .user)
        XCTAssertEqual(presentation.content, content)
    }

    func testCreation_AcceptsNilContent() {
        let presentation = MessagePresentation(role: .system, content: nil)
        XCTAssertNil(presentation.content)
    }

    // MARK: Presentation of a Domain message

    func testMessagePresentation_MapsRoleAndSegmentsContent() {
        let message = Message(role: .user, content: "Hello")
        let presentation = MessagePresentation(message: message)
        XCTAssertEqual(presentation.role, .user)
        XCTAssertEqual(
            presentation.content,
            MarkdownContent(segments: [.text("Hello")])
        )
    }

    func testMessagePresentation_EmptyMessageCarriesNoContent() {
        let message = Message(role: .assistant, content: "")
        let presentation = MessagePresentation(message: message)
        XCTAssertNil(presentation.content)
    }

    func testMessagePresentation_SegmentsFencedCodeBlocks() {
        let message = Message(
            role: .assistant,
            content: "Before\n```\ncode\n```\nAfter"
        )
        let presentation = MessagePresentation(message: message)
        XCTAssertEqual(presentation.role, .assistant)
        XCTAssertEqual(
            presentation.content?.segments,
            [
                .text("Before"),
                .codeBlock(content: "code"),
                .text("After"),
            ]
        )
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        let a = MessagePresentation(
            role: .assistant,
            content: MarkdownContent(segments: [.text("Hello")])
        )
        let b = MessagePresentation(
            role: .assistant,
            content: MarkdownContent(segments: [.text("Hello")])
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentRoleIsNotEqual() {
        let a = MessagePresentation(
            role: .user,
            content: MarkdownContent(segments: [.text("Hello")])
        )
        let b = MessagePresentation(
            role: .assistant,
            content: MarkdownContent(segments: [.text("Hello")])
        )
        XCTAssertNotEqual(a, b)
    }
}
