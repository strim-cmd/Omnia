import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class ConfigurationSerializerTests: XCTestCase {

    func testRoundTrip_PreservesValuesPerLevelAndKey() throws {
        let serializer = ConfigurationSerializer<Int>()
        let key = ConfigurationKey<Int>("retryCount")
        let snapshot: [ConfigurationLevel: [ConfigurationKey<Int>: Int]] = [
            .globalDefault: [key: 3],
            .workspaceOverride: [key: 5],
        ]

        let restored = try serializer.decode(from: serializer.encode(snapshot))

        XCTAssertEqual(restored[.globalDefault]?[key], 3)
        XCTAssertEqual(restored[.workspaceOverride]?[key], 5)
    }

    func testRoundTrip_MultipleKeysAcrossLevels() throws {
        let serializer = ConfigurationSerializer<String>()
        let nameKey = ConfigurationKey<String>("displayName")
        let sortKey = ConfigurationKey<String>("sortOrder")
        let snapshot: [ConfigurationLevel: [ConfigurationKey<String>: String]] = [
            .providerSettings: [nameKey: "OpenAI"],
            .capabilityPreference: [sortKey: "manual"],
            .globalDefault: [nameKey: "default"],
        ]

        let restored = try serializer.decode(from: serializer.encode(snapshot))

        XCTAssertEqual(restored[.providerSettings]?[nameKey], "OpenAI")
        XCTAssertEqual(restored[.capabilityPreference]?[sortKey], "manual")
        XCTAssertEqual(restored[.globalDefault]?[nameKey], "default")
    }

    func testRoundTrip_EmptySnapshot() throws {
        let serializer = ConfigurationSerializer<Int>()

        let restored = try serializer.decode(from: serializer.encode([:]))

        XCTAssertTrue(restored.isEmpty)
    }

    func testRoundTrip_CredentialReferencesAreStored_NotSecrets() throws {
        let serializer = ConfigurationSerializer<CredentialReference>()
        let key = ConfigurationKey<CredentialReference>("providerCredential")
        let reference = CredentialReference()
        let snapshot: [ConfigurationLevel: [ConfigurationKey<CredentialReference>: CredentialReference]] = [
            .providerSettings: [key: reference],
        ]

        let restored = try serializer.decode(from: serializer.encode(snapshot))

        XCTAssertEqual(restored[.providerSettings]?[key], reference)
    }

    func testEncode_IsDeterministic() throws {
        let serializer = ConfigurationSerializer<Int>()
        let key = ConfigurationKey<Int>("count")
        let snapshot: [ConfigurationLevel: [ConfigurationKey<Int>: Int]] = [
            .globalDefault: [key: 1],
        ]

        XCTAssertEqual(try serializer.encode(snapshot), try serializer.encode(snapshot))
    }

    func testDecode_CorruptDataThrowsStorageUnavailable() {
        let serializer = ConfigurationSerializer<Int>()

        XCTAssertThrowsError(try serializer.decode(from: Data("{ not valid json".utf8))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testDecode_UnknownLevelThrowsStorageUnavailable() throws {
        let serializer = ConfigurationSerializer<Int>()
        let entry = ConfigurationEntryDTO<Int>(key: "count", level: "bogus", value: 1)
        let data = try JSONEncoder().encode(ConfigurationValuesDTO(values: [entry]))

        XCTAssertThrowsError(try serializer.decode(from: data)) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
