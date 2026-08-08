import XCTest
@testable import OmniaDomain

final class ProviderLimitsTests: XCTestCase {

    func testCreation_ExposesStatedConstraints() {
        let limits = ProviderLimits(
            maxRequestsPerMinute: 60,
            maxTokensPerMinute: 90_000,
            maxContextTokens: 128_000
        )
        XCTAssertEqual(limits.maxRequestsPerMinute, 60)
        XCTAssertEqual(limits.maxTokensPerMinute, 90_000)
        XCTAssertEqual(limits.maxContextTokens, 128_000)
    }

    func testCreation_DefaultsToUnstatedConstraints() {
        let limits = ProviderLimits()
        XCTAssertNil(limits.maxRequestsPerMinute)
        XCTAssertNil(limits.maxTokensPerMinute)
        XCTAssertNil(limits.maxContextTokens)
    }

    func testCreation_MissingConstraintIsNil() {
        let limits = ProviderLimits(maxRequestsPerMinute: 60)
        XCTAssertEqual(limits.maxRequestsPerMinute, 60)
        XCTAssertNil(limits.maxTokensPerMinute)
        XCTAssertNil(limits.maxContextTokens)
    }

    func testEquality_SameConstraintsAreEqual() {
        let a = ProviderLimits(maxRequestsPerMinute: 60, maxTokensPerMinute: 90_000)
        let b = ProviderLimits(maxRequestsPerMinute: 60, maxTokensPerMinute: 90_000)
        XCTAssertEqual(a, b)
    }

    func testEquality_UnstatedConstraintsAreEqual() {
        let a = ProviderLimits()
        let b = ProviderLimits()
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentConstraintsAreNotEqual() {
        let a = ProviderLimits(maxRequestsPerMinute: 60)
        let b = ProviderLimits(maxRequestsPerMinute: 120)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_StatedAndUnstatedAreNotEqual() {
        let a = ProviderLimits()
        let b = ProviderLimits(maxContextTokens: 128_000)
        XCTAssertNotEqual(a, b)
    }

    func testImmutability_ConstraintsNeverChangeAfterCreation() {
        let limits = ProviderLimits(maxRequestsPerMinute: 60)
        XCTAssertEqual(limits.maxRequestsPerMinute, 60)
        XCTAssertEqual(limits.maxRequestsPerMinute, 60)
    }
}
