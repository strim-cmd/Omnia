import OmniaApplication
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

final class ProviderConnectionListItemTests: XCTestCase {

    private func connection() -> ProviderConnection {
        ProviderConnection(
            identity: ProviderIdentity(),
            capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
            metadata: ProviderMetadata(displayName: "Test Provider"),
            limits: ProviderLimits(
                maxRequestsPerMinute: nil,
                maxTokensPerMinute: nil,
                maxContextTokens: nil
            ),
            version: SemanticVersion(major: 1, minor: 0, patch: 0)
        )
    }

    // MARK: Creation

    func testCreation_ExposesIdentityDisplayNameAndState() {
        let identity = ProviderIdentity()
        let item = ProviderConnectionListItem(
            identity: identity,
            displayName: "Test Provider",
            state: .ready
        )
        XCTAssertEqual(item.identity, identity)
        XCTAssertEqual(item.displayName, "Test Provider")
        XCTAssertEqual(item.state, .ready)
    }

    // MARK: Derivation from a provider

    func testDerivation_MapsConnectionAndLifecycleState() {
        let connection = self.connection()
        let provider = Provider(connection: connection)
        let item = ProviderConnectionListItem(provider: provider)
        XCTAssertEqual(item.identity, connection.identity)
        XCTAssertEqual(item.displayName, "Test Provider")
        XCTAssertEqual(item.state, .registered)
    }

    func testDerivation_ReflectsTransitions() throws {
        let provider = Provider(connection: self.connection())
        try provider.transition(to: .validated)
        let item = ProviderConnectionListItem(provider: provider)
        XCTAssertEqual(item.state, .validated)
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        let identity = ProviderIdentity()
        let a = ProviderConnectionListItem(
            identity: identity,
            displayName: "Test Provider",
            state: .ready
        )
        let b = ProviderConnectionListItem(
            identity: identity,
            displayName: "Test Provider",
            state: .ready
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentStateIsNotEqual() {
        let identity = ProviderIdentity()
        let a = ProviderConnectionListItem(
            identity: identity,
            displayName: "Test Provider",
            state: .ready
        )
        let b = ProviderConnectionListItem(
            identity: identity,
            displayName: "Test Provider",
            state: .unavailable
        )
        XCTAssertNotEqual(a, b)
    }
}
