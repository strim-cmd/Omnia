import XCTest
@testable import OmniaPresentation

final class MessageBubbleWidthPolicyTests: XCTestCase {
    func testMaximumWidthIsEightyPercentOfCurrentContainer() {
        XCTAssertEqual(MessageBubbleWidthPolicy.maximumWidth(for: 320), 256)
        XCTAssertEqual(MessageBubbleWidthPolicy.maximumWidth(for: 800), 640)
    }

    func testShortIntrinsicContentKeepsMeasuredWidth() {
        XCTAssertEqual(
            MessageBubbleWidthPolicy.resolvedWidth(
                measuredWidth: 62,
                availableWidth: 320
            ),
            62
        )
    }

    func testLongContentIsCappedProportionally() {
        XCTAssertEqual(
            MessageBubbleWidthPolicy.resolvedWidth(
                measuredWidth: 500,
                availableWidth: 320
            ),
            256
        )
    }

    func testNonPositiveMeasurementsNeverProduceNegativeWidth() {
        XCTAssertEqual(
            MessageBubbleWidthPolicy.resolvedWidth(
                measuredWidth: -10,
                availableWidth: 320
            ),
            0
        )
        XCTAssertEqual(MessageBubbleWidthPolicy.maximumWidth(for: -320), 0)
    }
}
