import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class NavigationStateTests: XCTestCase {

    private let canonical = "550E8400-E29B-41D4-A716-446655440000"

    private func identity() throws -> ConversationIdentity {
        try XCTUnwrap(ConversationIdentity(restoring: canonical))
    }

    // MARK: Routes

    func testConversationListRoute() {
        let state = NavigationState(currentRoute: .conversationList)
        XCTAssertEqual(state.currentRoute, .conversationList)
    }

    func testConversationScreenRoute_CarriesTheConversationIdentity() throws {
        let identity = try identity()
        let state = NavigationState(
            currentRoute: .conversationScreen(conversation: identity)
        )
        XCTAssertEqual(
            state.currentRoute,
            .conversationScreen(conversation: identity)
        )
    }

    func testSettingsRoute() {
        let state = NavigationState(currentRoute: .settings)
        XCTAssertEqual(state.currentRoute, .settings)
    }

    // MARK: Equality

    func testEquality_SameRouteIsEqual() throws {
        let identity = try identity()
        let a = NavigationState(
            currentRoute: .conversationScreen(conversation: identity)
        )
        let b = NavigationState(
            currentRoute: .conversationScreen(conversation: identity)
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentRouteIsNotEqual() {
        let a = NavigationState(currentRoute: .conversationList)
        let b = NavigationState(currentRoute: .settings)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentConversationIsNotEqual() throws {
        let other = try XCTUnwrap(
            ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001")
        )
        let a = NavigationState(
            currentRoute: .conversationScreen(conversation: try identity())
        )
        let b = NavigationState(
            currentRoute: .conversationScreen(conversation: other)
        )
        XCTAssertNotEqual(a, b)
    }
}
