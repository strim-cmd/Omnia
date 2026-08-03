import XCTest
@testable import OmniaDomain

final class ConfigurationKeyTests: XCTestCase {

    func testInit_RetainsTheName() {
        let key = ConfigurationKey<String>("defaultModel")
        XCTAssertEqual(key.name, "defaultModel")
    }

    func testEquality_SameNameAndTypeIsEqual() {
        XCTAssertEqual(
            ConfigurationKey<String>("defaultModel"),
            ConfigurationKey<String>("defaultModel")
        )
    }

    func testEquality_DifferentNameIsNotEqual() {
        XCTAssertNotEqual(
            ConfigurationKey<String>("defaultModel"),
            ConfigurationKey<String>("otherModel")
        )
    }

    func testEquality_TypeIsPartOfTheKey() {
        XCTAssertNotEqual(
            AnyHashable(ConfigurationKey<String>("capacity")),
            AnyHashable(ConfigurationKey<Int>("capacity"))
        )
    }

    func testHashability_EqualKeysHashEqually() {
        let a = ConfigurationKey<Double>("temperature")
        let b = ConfigurationKey<Double>("temperature")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashability_UsableAsDictionaryKey() {
        var values: [ConfigurationKey<Int>: String] = [:]
        let key = ConfigurationKey<Int>("maxTokens")
        values[key] = "8k"
        XCTAssertEqual(values[key], "8k")
    }

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let key = ConfigurationKey<String>("defaultModel")
        let name = key.name
        let returned = await Task.detached {
            key.name
        }.value
        XCTAssertEqual(returned, name)
    }
}
