import XCTest
@testable import OmniaDomain

final class ConfigurationLevelTests: XCTestCase {

    func testLevels_DeclareAllFourConfigurationLevels() {
        let levels: Set<ConfigurationLevel> = [
            .providerSettings,
            .workspaceOverride,
            .globalDefault,
            .capabilityPreference,
        ]
        XCTAssertEqual(levels.count, 4)
    }

    func testLevels_AreDistinct() {
        XCTAssertNotEqual(ConfigurationLevel.providerSettings, .workspaceOverride)
        XCTAssertNotEqual(ConfigurationLevel.providerSettings, .globalDefault)
        XCTAssertNotEqual(ConfigurationLevel.providerSettings, .capabilityPreference)
        XCTAssertNotEqual(ConfigurationLevel.workspaceOverride, .globalDefault)
        XCTAssertNotEqual(ConfigurationLevel.workspaceOverride, .capabilityPreference)
        XCTAssertNotEqual(ConfigurationLevel.globalDefault, .capabilityPreference)
    }

    func testEquality_SameLevelIsEqual() {
        XCTAssertEqual(ConfigurationLevel.providerSettings, .providerSettings)
        XCTAssertEqual(ConfigurationLevel.globalDefault, .globalDefault)
    }
}
