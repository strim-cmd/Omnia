import XCTest
@testable import OmniaDomain

final class MessageTests: XCTestCase {

    func testCreation_ExposesRoleAndContent() {
        let message = Message(role: .user, content: "Hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
    }

    func testEquality_SameRoleAndContentAreEqual() {
        let a = Message(role: .user, content: "Hello")
        let b = Message(role: .user, content: "Hello")
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentContentIsNotEqual() {
        let a = Message(role: .user, content: "Hello")
        let b = Message(role: .user, content: "Hi")
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentRoleIsNotEqual() {
        let a = Message(role: .user, content: "Hello")
        let b = Message(role: .assistant, content: "Hello")
        XCTAssertNotEqual(a, b)
    }

    func testRoles_AreDistinct() {
        XCTAssertNotEqual(MessageRole.system, .user)
        XCTAssertNotEqual(MessageRole.system, .assistant)
        XCTAssertNotEqual(MessageRole.user, .assistant)
    }

    func testRoles_SupportAllConversationContributors() {
        XCTAssertEqual(MessageRole.system, .system)
        XCTAssertEqual(MessageRole.user, .user)
        XCTAssertEqual(MessageRole.assistant, .assistant)
    }

    func testImmutability_RoleAndContentNeverChangeAfterCreation() {
        let message = Message(role: .assistant, content: "42")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "42")
        XCTAssertEqual(message.content, "42")
    }
}
