import XCTest
@testable import OmniaDomain

final class ProviderMetadataTests: XCTestCase {

    func testCreation_ExposesTheDisplayName() {
        let metadata = ProviderMetadata(displayName: "OpenAI")
        XCTAssertEqual(metadata.displayName, "OpenAI")
    }

    func testEquality_SameDisplayNameIsEqual() {
        let a = ProviderMetadata(displayName: "OpenAI")
        let b = ProviderMetadata(displayName: "OpenAI")
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentDisplayNamesAreNotEqual() {
        let a = ProviderMetadata(displayName: "OpenAI")
        let b = ProviderMetadata(displayName: "Anthropic")
        XCTAssertNotEqual(a, b)
    }

    func testImmutability_DisplayNameNeverChangesAfterCreation() {
        let metadata = ProviderMetadata(displayName: "OpenAI")
        XCTAssertEqual(metadata.displayName, "OpenAI")
        XCTAssertEqual(metadata.displayName, "OpenAI")
    }
}
