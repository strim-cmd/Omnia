import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class WorkspaceSerializerTests: XCTestCase {

    private let serializer = WorkspaceSerializer()

    func testRoundTrip_PreservesWorkspaceContent() throws {
        let identity = WorkspaceIdentity()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let providerA = ProviderIdentity()
        let workspace = Workspace(
            identity: identity,
            name: "Design",
            conversationIdentities: [conversationA, conversationB],
            providerIdentities: [providerA]
        )

        let restored = try serializer.decode(from: serializer.encode(workspace))

        XCTAssertEqual(restored, workspace)
    }

    func testRoundTrip_PreservesEmptyMembership() throws {
        let workspace = Workspace(identity: WorkspaceIdentity(), name: "Empty")

        let restored = try serializer.decode(from: serializer.encode(workspace))

        XCTAssertEqual(restored, workspace)
    }

    func testEncode_IsDeterministic() throws {
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Design",
            conversationIdentities: [ConversationIdentity()]
        )

        XCTAssertEqual(try serializer.encode(workspace), try serializer.encode(workspace))
    }

    func testEncode_StoresMembershipSorted() throws {
        let a = ConversationIdentity()
        let b = ConversationIdentity()
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Design",
            conversationIdentities: [a, b]
        )

        let json = String(data: try serializer.encode(workspace), encoding: .utf8) ?? ""
        let sorted = [a.canonicalString, b.canonicalString].sorted()

        XCTAssertTrue(json.contains(sorted[0]))
        XCTAssertTrue(json.contains(sorted[1]))
    }

    func testDecode_CorruptDataThrowsStorageUnavailable() {
        XCTAssertThrowsError(try serializer.decode(from: Data("{ not valid json".utf8))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
