import XCTest
@testable import OmniaDomain

final class ConfigurationValueTests: XCTestCase {

    func testCreation_ExposesValueAndLevel() {
        let configuration = ConfigurationValue(value: "https://api.example.com", level: .providerSettings)
        XCTAssertEqual(configuration.value, "https://api.example.com")
        XCTAssertEqual(configuration.level, .providerSettings)
    }

    func testCreation_SupportsTypedValues() {
        let requests = ConfigurationValue(value: 60, level: .workspaceOverride)
        XCTAssertEqual(requests.value, 60)

        let enabled = ConfigurationValue(value: true, level: .globalDefault)
        XCTAssertEqual(enabled.value, true)
    }

    func testEquality_SameValueAndLevelAreEqual() {
        let a = ConfigurationValue(value: 60, level: .workspaceOverride)
        let b = ConfigurationValue(value: 60, level: .workspaceOverride)
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentValueIsNotEqual() {
        let a = ConfigurationValue(value: 60, level: .workspaceOverride)
        let b = ConfigurationValue(value: 120, level: .workspaceOverride)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentLevelIsNotEqual() {
        let a = ConfigurationValue(value: 60, level: .workspaceOverride)
        let b = ConfigurationValue(value: 60, level: .globalDefault)
        XCTAssertNotEqual(a, b)
    }

    func testImmutability_ValueAndLevelNeverChangeAfterCreation() {
        let configuration = ConfigurationValue(value: 60, level: .providerSettings)
        XCTAssertEqual(configuration.value, 60)
        XCTAssertEqual(configuration.level, .providerSettings)
        XCTAssertEqual(configuration.level, .providerSettings)
    }
}
