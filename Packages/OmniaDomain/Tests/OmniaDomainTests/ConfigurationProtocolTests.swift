import XCTest
@testable import OmniaDomain

private let modelKey = ConfigurationKey<String>("model")
private let temperatureKey = ConfigurationKey<Double>("temperature")
private let maxTokensKey = ConfigurationKey<Int>("maxTokens")

private struct StubConfiguration<Stored: Equatable & Sendable>: ConfigurationProtocol {
    let stored: Stored?

    func value<Value: Equatable & Sendable>(for key: ConfigurationKey<Value>) -> Value? {
        stored as? Value
    }
}

final class ConfigurationProtocolTests: XCTestCase {

    func testValue_ReturnsTheTypedConfiguredValue() {
        let configuration = StubConfiguration<String>(stored: "gpt-4o")
        XCTAssertEqual(configuration.value(for: modelKey), "gpt-4o")
    }

    func testValue_ReturnsNilWhenUnset() {
        let configuration = StubConfiguration<String>(stored: nil)
        XCTAssertNil(configuration.value(for: modelKey))
    }

    func testValue_TypedAccessDoesNotCoerceOtherTypes() {
        let configuration = StubConfiguration<String>(stored: "gpt-4o")
        XCTAssertEqual(configuration.value(for: modelKey), "gpt-4o")
        XCTAssertNil(configuration.value(for: temperatureKey))
    }

    func testValueWithDefault_UsesDefaultWhenUnset() {
        let configuration = StubConfiguration<String>(stored: nil)
        XCTAssertEqual(configuration.value(for: modelKey, default: "default-model"), "default-model")
    }

    func testValueWithDefault_SetValueWinsOverDefault() {
        let configuration = StubConfiguration<String>(stored: "gpt-4o")
        XCTAssertEqual(configuration.value(for: modelKey, default: "default-model"), "gpt-4o")
    }

    func testValueWithDefault_DefaultsAreTyped() {
        let configuration = StubConfiguration<Int>(stored: nil)
        XCTAssertEqual(configuration.value(for: maxTokensKey, default: 4_096), 4_096)
    }

    func testProtocol_ContainsNoResolutionLogic() {
        // The protocol exposes values and defaults only; cross-level resolution
        // belongs to ConfigurationResolutionPolicy.
        let configuration = StubConfiguration<String>(stored: "gpt-4o")
        XCTAssertEqual(configuration.value(for: modelKey, default: "default"), "gpt-4o")
    }

    func testSendability_ShareConfigurationAcrossConcurrencyDomain() async {
        let configuration = StubConfiguration<String>(stored: "gpt-4o")
        let value: String? = await Task.detached {
            configuration.value(for: modelKey)
        }.value
        XCTAssertEqual(value, "gpt-4o")
    }
}
