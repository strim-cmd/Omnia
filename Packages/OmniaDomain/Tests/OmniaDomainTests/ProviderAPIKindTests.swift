import XCTest
@testable import OmniaDomain

final class ProviderAPIKindTests: XCTestCase {

    func testDefault_IsTheOpenAICompatibleFamily() {
        XCTAssertEqual(ProviderAPIKind.default, .openAICompatible)
        XCTAssertEqual(ProviderAPIKind.default.rawValue, "openAICompatible")
    }

    func testCases_DeclareBothAPIFamilies() {
        XCTAssertEqual(
            ProviderAPIKind.allCases,
            [.openAICompatible, .gemini]
        )
        XCTAssertEqual(ProviderAPIKind.gemini.rawValue, "gemini")
    }

    func testEquality_ContentEqualIsEqual() {
        XCTAssertEqual(ProviderAPIKind.gemini, ProviderAPIKind.gemini)
        XCTAssertNotEqual(ProviderAPIKind.gemini, ProviderAPIKind.openAICompatible)
    }

    func testCodable_RoundTripsThroughJSON() throws {
        for kind in ProviderAPIKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(ProviderAPIKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testCodable_DecodesStableRawValue() throws {
        let data = Data(#""gemini""#.utf8)
        let decoded = try JSONDecoder().decode(ProviderAPIKind.self, from: data)
        XCTAssertEqual(decoded, .gemini)
    }
}
