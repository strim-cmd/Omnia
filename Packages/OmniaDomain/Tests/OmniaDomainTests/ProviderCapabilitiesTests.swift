import XCTest
@testable import OmniaDomain

final class ProviderCapabilitiesTests: XCTestCase {

    func testCreation_RetainsDeclaredCapabilities() {
        let capabilities = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        XCTAssertEqual(capabilities.capabilities, [.textGeneration, .streaming])
    }

    func testContains_ReportsDeliveredCapabilities() {
        let capabilities = ProviderCapabilities(capabilities: [.textGeneration, .conversation])
        XCTAssertTrue(capabilities.contains(.textGeneration))
        XCTAssertTrue(capabilities.contains(.conversation))
        XCTAssertFalse(capabilities.contains(.streaming))
        XCTAssertFalse(capabilities.contains(.vision))
    }

    func testContains_EmptySetDeliversNothing() {
        let capabilities = ProviderCapabilities(capabilities: [])
        XCTAssertFalse(capabilities.contains(.textGeneration))
    }

    func testEquality_ContentEqualIsEqual() {
        let a = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        let b = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        XCTAssertEqual(a, b)
    }

    func testEquality_OrderDoesNotMatter() {
        let a = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        let b = ProviderCapabilities(capabilities: [.streaming, .textGeneration])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentContentIsNotEqual() {
        let a = ProviderCapabilities(capabilities: [.textGeneration])
        let b = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        XCTAssertNotEqual(a, b)
    }

    func testHashability_EqualCapabilitiesHashEqually() {
        let a = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        let b = ProviderCapabilities(capabilities: [.streaming, .textGeneration])
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
