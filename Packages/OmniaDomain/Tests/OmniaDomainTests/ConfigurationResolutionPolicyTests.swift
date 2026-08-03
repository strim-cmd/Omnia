import XCTest
@testable import OmniaDomain

private let modelKey = ConfigurationKey<String>("model")

final class ConfigurationResolutionPolicyTests: XCTestCase {

    private var policy: ConfigurationResolutionPolicy { ConfigurationResolutionPolicy() }

    // MARK: Resolution order

    func testResolution_ProviderSettingsWinOverAllLowerLevels() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .providerSettings: [modelKey: "provider-model"],
            .workspaceOverride: [modelKey: "workspace-model"],
            .globalDefault: [modelKey: "default-model"],
            .capabilityPreference: [modelKey: "preference-model"],
        ]
        XCTAssertEqual(policy.resolve(modelKey, in: values), "provider-model")
    }

    func testResolution_WorkspaceOverrideWinsWhenProviderSettingsUnset() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .workspaceOverride: [modelKey: "workspace-model"],
            .globalDefault: [modelKey: "default-model"],
        ]
        XCTAssertEqual(policy.resolve(modelKey, in: values), "workspace-model")
    }

    func testResolution_GlobalDefaultWinsWhenHigherLevelsUnset() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .globalDefault: [modelKey: "default-model"],
            .capabilityPreference: [modelKey: "preference-model"],
        ]
        XCTAssertEqual(policy.resolve(modelKey, in: values), "default-model")
    }

    func testResolution_CapabilityPreferenceUsedAsLastLevel() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .capabilityPreference: [modelKey: "preference-model"],
        ]
        XCTAssertEqual(policy.resolve(modelKey, in: values), "preference-model")
    }

    func testResolution_ReturnsNilWhenNoLevelSetsTheKey() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [:]
        XCTAssertNil(policy.resolve(modelKey, in: values))
    }

    // MARK: Determinism

    func testResolution_IsDeterministicForEqualInput() {
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .workspaceOverride: [modelKey: "workspace-model"],
            .globalDefault: [modelKey: "default-model"],
        ]
        for _ in 0..<16 {
            XCTAssertEqual(policy.resolve(modelKey, in: values), "workspace-model")
        }
    }

    func testResolution_IgnoresLevelsOutsideTheFixedOrder() {
        // All levels are part of the fixed order; a value is only honored at
        // its own level's position.
        let values: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .capabilityPreference: [modelKey: "preference-model"],
            .workspaceOverride: [modelKey: "workspace-model"],
        ]
        XCTAssertEqual(policy.resolve(modelKey, in: values), "workspace-model")
    }

    func testResolution_TypedKeysNeverMixValueTypes() {
        let intKey = ConfigurationKey<Int>("limit")
        let stringKey = ConfigurationKey<String>("limit")
        let values: [ConfigurationLevel: [ConfigurationKey<Int>: Int]] = [
            .providerSettings: [intKey: 60],
        ]
        XCTAssertEqual(policy.resolve(intKey, in: values), 60)
        XCTAssertEqual(policy.resolve(stringKey, in: [:]), nil)
    }

    // MARK: Order definition

    func testResolutionOrder_IsHighestPriorityFirst() {
        XCTAssertEqual(
            ConfigurationResolutionPolicy.resolutionOrder,
            [
                .providerSettings,
                .workspaceOverride,
                .globalDefault,
                .capabilityPreference,
            ]
        )
    }
}
