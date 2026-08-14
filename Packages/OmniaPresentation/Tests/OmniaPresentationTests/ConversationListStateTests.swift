import Foundation
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

    func testSections_GroupAtLocalCalendarBoundariesIncludingOldAndFutureDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 3_600))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 14, hour: 0, minute: 30))
        )
        func row(_ suffix: String, days: Int) throws -> ConversationListItem {
            let identity = try XCTUnwrap(
                ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-4466554400\(suffix)")
            )
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: days, to: now))
            return ConversationListItem(
                identity: identity,
                displayTitle: suffix,
                displayPreview: nil,
                createdAt: date,
                updatedAt: date
            )
        }
        let state = ConversationListState(items: [
            try row("04", days: 2),
            try row("00", days: 0),
            try row("01", days: -1),
            try row("02", days: -5),
            try row("03", days: -30),
        ])

        let sections = state.sections(now: now, calendar: calendar)

        XCTAssertEqual(
            sections.map(\.group),
            [.future, .today, .yesterday, .previousSevenDays, .older]
        )
        XCTAssertEqual(sections.flatMap(\.items).map(\.displayTitle), ["04", "00", "01", "02", "03"])
    }

    func testGroup_UsesCalendarDayInsteadOfElapsedTwentyFourHours() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 0, minute: 15))
        )
        let previousDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 23, minute: 55))
        )

        XCTAssertEqual(
            ConversationListState.group(for: previousDay, now: now, calendar: calendar),
            .yesterday
        )
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
