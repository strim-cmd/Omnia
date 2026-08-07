import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalWorkspace = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalConversation = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
private let canonicalProvider = "1CE9122D-9DDE-11D1-80B4-00C04FD430C8"

private func makeIdentity(_ canonical: String) throws -> WorkspaceIdentity {
    try XCTUnwrap(WorkspaceIdentity(restoring: canonical))
}

final class WorkspaceTests: XCTestCase {

    // MARK: Creation

    func testCreation_RetainsIdentityNameAndMembership() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))

        let workspace = Workspace(
            identity: identity,
            name: "Research",
            conversationIdentities: [conversation],
            providerIdentities: [provider]
        )

        XCTAssertEqual(workspace.identity, identity)
        XCTAssertEqual(workspace.name, "Research")
        XCTAssertEqual(workspace.conversationIdentities, [conversation])
        XCTAssertEqual(workspace.providerIdentities, [provider])
    }

    func testCreation_DefaultsToEmptyMembership() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let workspace = Workspace(identity: identity, name: "Research")
        XCTAssertTrue(workspace.conversationIdentities.isEmpty)
        XCTAssertTrue(workspace.providerIdentities.isEmpty)
    }

    // MARK: Membership

    func testContains_ReportsMembershipByIdentity() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let otherConversation = ConversationIdentity()
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))
        let otherProvider = ProviderIdentity()

        let workspace = Workspace(
            identity: identity,
            name: "Research",
            conversationIdentities: [conversation],
            providerIdentities: [provider]
        )

        XCTAssertTrue(workspace.contains(conversation: conversation))
        XCTAssertFalse(workspace.contains(conversation: otherConversation))
        XCTAssertTrue(workspace.contains(provider: provider))
        XCTAssertFalse(workspace.contains(provider: otherProvider))
    }

    // MARK: Mutation returns new values

    func testAddingConversation_ReturnsWorkspaceWithTheNewMember() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let workspace = Workspace(identity: identity, name: "Research")

        let updated = workspace.adding(conversation: conversation)

        XCTAssertFalse(workspace.contains(conversation: conversation))
        XCTAssertTrue(updated.contains(conversation: conversation))
    }

    func testAddingProvider_ReturnsWorkspaceWithTheNewMember() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))
        let workspace = Workspace(identity: identity, name: "Research")

        let updated = workspace.adding(provider: provider)

        XCTAssertFalse(workspace.contains(provider: provider))
        XCTAssertTrue(updated.contains(provider: provider))
    }

    func testRemovingConversation_ReturnsWorkspaceWithoutTheMember() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let workspace = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])

        let updated = workspace.removing(conversation: conversation)

        XCTAssertTrue(workspace.contains(conversation: conversation))
        XCTAssertFalse(updated.contains(conversation: conversation))
    }

    func testRemovingProvider_ReturnsWorkspaceWithoutTheMember() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))
        let workspace = Workspace(identity: identity, name: "Research", providerIdentities: [provider])

        let updated = workspace.removing(provider: provider)

        XCTAssertTrue(workspace.contains(provider: provider))
        XCTAssertFalse(updated.contains(provider: provider))
    }

    func testAddingIsIdempotentForAnExistingMember() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let workspace = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])

        let updated = workspace.adding(conversation: conversation)

        XCTAssertEqual(updated.conversationIdentities, [conversation])
    }

    func testMembershipChanges_PreserveOtherMembership() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let provider = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))

        let workspace = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])
        let updated = workspace.adding(provider: provider).removing(conversation: conversation)

        XCTAssertTrue(updated.contains(provider: provider))
        XCTAssertFalse(updated.contains(conversation: conversation))
    }

    // MARK: Equality

    func testEquality_ContentEqualIsEqual() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let a = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])
        let b = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentIdentityIsNotEqual() throws {
        let a = Workspace(identity: WorkspaceIdentity(), name: "Research")
        let b = Workspace(identity: WorkspaceIdentity(), name: "Research")
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentMembershipIsNotEqual() throws {
        let identity = try makeIdentity(canonicalWorkspace)
        let conversation = try XCTUnwrap(ConversationIdentity(restoring: canonicalConversation))
        let a = Workspace(identity: identity, name: "Research")
        let b = Workspace(identity: identity, name: "Research", conversationIdentities: [conversation])
        XCTAssertNotEqual(a, b)
    }
}
