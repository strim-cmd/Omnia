import Foundation
import XCTest
@testable import OmniaDomain

private let canonicalWorkspace = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalConversation = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
private let canonicalProvider = "1CE9122D-9DDE-11D1-80B4-00C04FD430C8"

private func isWellFormedCanonical(_ value: String) -> Bool {
    let parts = value.split(separator: "-")
    let lengths = [8, 4, 4, 4, 12]
    guard parts.count == lengths.count else { return false }
    for (part, expected) in zip(parts, lengths) where part.count != expected {
        return false
    }
    return parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
}

final class AggregateIdentityTests: XCTestCase {

    // MARK: WorkspaceIdentity

    func testWorkspaceIdentity_ProducesWellFormedCanonicalForm() {
        for _ in 0..<32 {
            XCTAssertTrue(isWellFormedCanonical(WorkspaceIdentity().canonicalString))
        }
    }

    func testWorkspaceIdentity_RestoresFromCanonicalForm() throws {
        let identifier = WorkspaceIdentity()
        let restored = try XCTUnwrap(WorkspaceIdentity(restoring: identifier.canonicalString))
        XCTAssertEqual(restored, identifier)
    }

    func testWorkspaceIdentity_MalformedInputIsRejected() {
        XCTAssertNil(WorkspaceIdentity(restoring: "not-a-uuid"))
        XCTAssertNil(WorkspaceIdentity(restoring: "550E8400"))
        XCTAssertNil(WorkspaceIdentity(restoring: ""))
    }

    func testWorkspaceIdentity_CodableRoundTripsExactly() throws {
        let identifier = WorkspaceIdentity()
        let data = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(WorkspaceIdentity.self, from: data)
        XCTAssertEqual(decoded, identifier)
    }

    // MARK: ConversationIdentity

    func testConversationIdentity_ProducesWellFormedCanonicalForm() {
        for _ in 0..<32 {
            XCTAssertTrue(isWellFormedCanonical(ConversationIdentity().canonicalString))
        }
    }

    func testConversationIdentity_RestoresFromCanonicalForm() throws {
        let identifier = ConversationIdentity()
        let restored = try XCTUnwrap(ConversationIdentity(restoring: identifier.canonicalString))
        XCTAssertEqual(restored, identifier)
    }

    func testConversationIdentity_MalformedInputIsRejected() {
        XCTAssertNil(ConversationIdentity(restoring: "not-a-uuid"))
        XCTAssertNil(ConversationIdentity(restoring: "6BA7B810-9DAD-11D1-80B4-00C04FD430C"))
    }

    func testConversationIdentity_CodableRoundTripsExactly() throws {
        let identifier = ConversationIdentity()
        let data = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(ConversationIdentity.self, from: data)
        XCTAssertEqual(decoded, identifier)
    }

    // MARK: Distinct concepts

    func testIdentity_EqualUnderlyingValuesAreEqualWithinAConcept() throws {
        let a = try XCTUnwrap(WorkspaceIdentity(restoring: canonicalWorkspace))
        let b = try XCTUnwrap(WorkspaceIdentity(restoring: canonicalWorkspace))
        XCTAssertEqual(a, b)
    }

    func testIdentity_DifferentUnderlyingValuesAreNotEqual() throws {
        let a = try XCTUnwrap(WorkspaceIdentity(restoring: canonicalWorkspace))
        let b = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        XCTAssertNotEqual(AnyHashable(a), AnyHashable(b))
    }

    func testIdentity_AggregateConceptsAreNeverInterchangeable() throws {
        let workspace = try XCTUnwrap(WorkspaceIdentity(restoring: canonicalWorkspace))
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalWorkspace))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalWorkspace))

        XCTAssertNotEqual(AnyHashable(workspace), AnyHashable(conversation))
        XCTAssertNotEqual(AnyHashable(workspace), AnyHashable(provider))
        XCTAssertNotEqual(AnyHashable(conversation), AnyHashable(provider))
    }

    func testIdentity_RestoredAggregateIdentitiesEqualTheirCanonicalForm() throws {
        let workspace = try XCTUnwrap(WorkspaceIdentity(restoring: canonicalWorkspace))
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))

        XCTAssertEqual(workspace.canonicalString, canonicalWorkspace)
        XCTAssertEqual(conversation.canonicalString, canonicalConversation)
        XCTAssertEqual(provider.canonicalString, canonicalProvider)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let workspace = WorkspaceIdentity()
        let conversation = ConversationIdentity()
        let canonical = workspace.canonicalString
        let returned = await Task.detached {
            (workspace.canonicalString, conversation.canonicalString)
        }.value
        XCTAssertEqual(returned.0, canonical)
    }
}
