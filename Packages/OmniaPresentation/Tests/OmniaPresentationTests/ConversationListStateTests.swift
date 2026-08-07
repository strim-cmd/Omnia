import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class ConversationListStateTests: XCTestCase {

    private let canonical = "550E8400-E29B-41D4-A716-446655440000"

    private func identity() throws -> ConversationIdentity {
        try XCTUnwrap(ConversationIdentity(restoring: canonical))
    }

    private func item() throws -> ConversationListItem {
        ConversationListItem(
            identity: try identity(),
            displayTitle: "Title",
            displayPreview: "Preview"
        )
    }

    // MARK: Empty and error conditions

    func testEmpty_WhenNoItems() {
        let state = ConversationListState(items: [])
        XCTAssertTrue(state.isEmpty)
        XCTAssertFalse(state.hasError)
    }

    func testEmpty_ReflectsItems() throws {
        let state = ConversationListState(items: [try item()])
        XCTAssertFalse(state.isEmpty)
    }

    func testFailure_ReportsTheTypedError() {
        let state = ConversationListState(
            items: [],
            failure: .storageUnavailable
        )
        XCTAssertTrue(state.hasError)
        XCTAssertEqual(state.failure, .storageUnavailable)
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() throws {
        let a = ConversationListState(items: [try item()])
        let b = ConversationListState(items: [try item()])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentFailureIsNotEqual() throws {
        let a = ConversationListState(items: [try item()], failure: nil)
        let b = ConversationListState(
            items: [try item()],
            failure: .storageUnavailable
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentItemsAreNotEqual() throws {
        let other = try XCTUnwrap(
            ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001")
        )
        let a = ConversationListState(items: [try item()])
        let b = ConversationListState(
            items: [
                ConversationListItem(
                    identity: other,
                    displayTitle: "Other",
                    displayPreview: nil
                ),
            ]
        )
        XCTAssertNotEqual(a, b)
    }
}
