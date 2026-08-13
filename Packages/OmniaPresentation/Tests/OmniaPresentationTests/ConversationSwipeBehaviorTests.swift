import XCTest
@testable import OmniaPresentation

final class ConversationSwipeBehaviorTests: XCTestCase {
    func testGeometryMatchesSingleCircularActionSpecification() {
        XCTAssertEqual(ConversationSwipeBehavior.actionDiameter, 54)
        XCTAssertEqual(ConversationSwipeBehavior.trailingMargin, 14)
        XCTAssertEqual(ConversationSwipeBehavior.cardActionGap, 10)
        XCTAssertEqual(ConversationSwipeBehavior.revealDistance, 78)
    }

    func testOnlyHorizontalDominantDragControlsReveal() {
        XCTAssertEqual(
            ConversationSwipeBehavior.horizontalTranslation(width: -30, height: 8),
            -30
        )
        XCTAssertNil(
            ConversationSwipeBehavior.horizontalTranslation(width: -8, height: 30)
        )
    }

    func testClosedRowReturnsClosedBeforeThresholdAndOpensAtThreshold() {
        XCTAssertFalse(
            ConversationSwipeBehavior.settlesOpen(wasOpen: false, dragTranslation: -38)
        )
        XCTAssertTrue(
            ConversationSwipeBehavior.settlesOpen(wasOpen: false, dragTranslation: -39)
        )
    }

    func testOpenRowClosesOnlyAfterRightwardThreshold() {
        XCTAssertTrue(
            ConversationSwipeBehavior.settlesOpen(wasOpen: true, dragTranslation: 38)
        )
        XCTAssertFalse(
            ConversationSwipeBehavior.settlesOpen(wasOpen: true, dragTranslation: 39)
        )
    }

    func testOffsetAppliesResistancePastBothRestingBounds() {
        XCTAssertEqual(
            ConversationSwipeBehavior.offset(isOpen: false, dragTranslation: 20),
            4
        )
        XCTAssertEqual(
            ConversationSwipeBehavior.offset(isOpen: false, dragTranslation: -98),
            -82
        )
    }
}
