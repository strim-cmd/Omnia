import Foundation
import XCTest
@testable import OmniaFoundation

final class SemanticVersionTests: XCTestCase {

    // MARK: Construction

    func testConstruction_ReportsComponents() {
        let version = SemanticVersion(major: 17, minor: 4, patch: 1)
        XCTAssertEqual(version.major, 17)
        XCTAssertEqual(version.minor, 4)
        XCTAssertEqual(version.patch, 1)
    }

    func testConstruction_ZeroComponentsAreSupported() {
        let version = SemanticVersion(major: 0, minor: 0, patch: 0)
        XCTAssertEqual(version, SemanticVersion(major: 0, minor: 0, patch: 0))
    }

    // MARK: Description

    func testDescription_IsMajorMinorPatch() {
        XCTAssertEqual(SemanticVersion(major: 17, minor: 4, patch: 1).description, "17.4.1")
    }

    func testDescription_ZeroPaddedFormIsNotInvented() {
        XCTAssertEqual(SemanticVersion(major: 2, minor: 0, patch: 0).description, "2.0.0")
    }

    // MARK: Equality

    func testEquality_SameComponentsAreEqual() {
        let a = SemanticVersion(major: 17, minor: 4, patch: 1)
        let b = SemanticVersion(major: 17, minor: 4, patch: 1)
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentComponentsAreNotEqual() {
        let base = SemanticVersion(major: 17, minor: 4, patch: 1)
        XCTAssertNotEqual(base, SemanticVersion(major: 18, minor: 4, patch: 1))
        XCTAssertNotEqual(base, SemanticVersion(major: 17, minor: 5, patch: 1))
        XCTAssertNotEqual(base, SemanticVersion(major: 17, minor: 4, patch: 2))
    }

    // MARK: Ordering

    func testOrdering_OrdersDeterministically() {
        let versions = [
            SemanticVersion(major: 1, minor: 0, patch: 0),
            SemanticVersion(major: 1, minor: 0, patch: 1),
            SemanticVersion(major: 1, minor: 2, patch: 0),
            SemanticVersion(major: 2, minor: 0, patch: 0),
        ]
        XCTAssertEqual(versions.sorted(), versions)
    }

    func testOrdering_MajorDominatesMinorAndPatch() {
        let major = SemanticVersion(major: 2, minor: 0, patch: 0)
        let minor = SemanticVersion(major: 1, minor: 99, patch: 99)
        XCTAssertGreaterThan(major, minor)
        XCTAssertLessThan(minor, major)
    }

    func testOrdering_MinorDominatesPatch() {
        let minor = SemanticVersion(major: 1, minor: 2, patch: 0)
        let patch = SemanticVersion(major: 1, minor: 1, patch: 99)
        XCTAssertGreaterThan(minor, patch)
        XCTAssertLessThan(patch, minor)
    }

    func testOrdering_ConsistentWithEquality() {
        let a = SemanticVersion(major: 17, minor: 4, patch: 1)
        let b = SemanticVersion(major: 17, minor: 4, patch: 1)
        XCTAssertFalse(a < b)
        XCTAssertFalse(b < a)
        XCTAssertEqual(a, b)
    }

    func testOrdering_BoundaryComparison() {
        let atLeast = SemanticVersion(major: 17, minor: 0, patch: 0)
        XCTAssertGreaterThanOrEqual(SemanticVersion(major: 17, minor: 0, patch: 0), atLeast)
        XCTAssertLessThan(SemanticVersion(major: 16, minor: 9, patch: 9), atLeast)
    }

    // MARK: Value semantics

    func testValueSemantics_VersionsAreImmutableValues() {
        let original = SemanticVersion(major: 17, minor: 4, patch: 1)
        var copy = original
        copy = SemanticVersion(major: 18, minor: 0, patch: 0)
        XCTAssertEqual(original, SemanticVersion(major: 17, minor: 4, patch: 1))
        XCTAssertEqual(copy, SemanticVersion(major: 18, minor: 0, patch: 0))
        XCTAssertNotEqual(original, copy)
    }

    // MARK: Sendability

    func testSendability_UsableInSendableClosure() {
        let version = SemanticVersion(major: 17, minor: 4, patch: 1)
        let expected = "17.4.1"
        let read: @Sendable () -> String = { version.description }
        XCTAssertEqual(read(), expected)
    }
}
