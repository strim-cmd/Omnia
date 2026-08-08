import OmniaDomain
import XCTest
@testable import OmniaApplication

final class SendMessageRequestTests: XCTestCase {

    private let canonicalConversation = "550E8400-E29B-41D4-A716-446655440000"

    private func conversation() throws -> ConversationIdentity {
        try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
    }

    private func provider() throws -> ProviderIdentity {
        try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001"))
    }

    // MARK: Creation

    func testCreation_ExposesConversationAndMessage() throws {
        let message = Message(role: .user, content: "Hello")
        let request = SendMessageRequest(conversation: try conversation(), message: message)
        XCTAssertEqual(request.conversation, try conversation())
        XCTAssertEqual(request.message, message)
    }

    func testSelectionPreferences_DefaultToNil() throws {
        let request = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        XCTAssertNil(request.userSelection)
        XCTAssertNil(request.workspacePreference)
        XCTAssertNil(request.capabilityPreference)
    }

    func testCreation_ExposesSelectionPreferences() throws {
        let user = try provider()
        let workspace = try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440002"))
        let capability = try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440003"))
        let request = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello"),
            userSelection: user,
            workspacePreference: workspace,
            capabilityPreference: capability
        )
        XCTAssertEqual(request.userSelection, user)
        XCTAssertEqual(request.workspacePreference, workspace)
        XCTAssertEqual(request.capabilityPreference, capability)
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() throws {
        let a = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        let b = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentConversationIsNotEqual() throws {
        let other = try XCTUnwrap(ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440010"))
        let a = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        let b = SendMessageRequest(
            conversation: other,
            message: Message(role: .user, content: "Hello")
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentMessageIsNotEqual() throws {
        let a = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        let b = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .assistant, content: "Hello")
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentSelectionPreferenceIsNotEqual() throws {
        let user = try provider()
        let a = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        let b = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello"),
            userSelection: user
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: Immutability

    func testImmutability_ValuesNeverChangeAfterCreation() throws {
        let request = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello"),
            userSelection: try provider()
        )
        XCTAssertEqual(request.conversation, try conversation())
        XCTAssertEqual(request.message, Message(role: .user, content: "Hello"))
        XCTAssertEqual(request.userSelection, try provider())
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let request = SendMessageRequest(
            conversation: try conversation(),
            message: Message(role: .user, content: "Hello")
        )
        let returned = await Task.detached {
            request
        }.value
        XCTAssertEqual(returned, request)
    }
}
