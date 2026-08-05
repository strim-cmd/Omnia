import Foundation
import XCTest
import OmniaDomain
import OmniaFoundation
@testable import OmniaInfrastructure

final class ProviderSerializerTests: XCTestCase {

    private let serializer = ProviderSerializer()

    private func makeConnection() -> ProviderConnection {
        ProviderConnection(
            identity: ProviderIdentity(),
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .streaming]),
            metadata: ProviderMetadata(displayName: "Test Provider"),
            limits: ProviderLimits(maxRequestsPerMinute: 10, maxTokensPerMinute: 100, maxContextTokens: 4000),
            version: SemanticVersion(major: 1, minor: 2, patch: 3)
        )
    }

    /// Creates a provider whose lifecycle has reached `state` through its own
    /// legal transitions.
    private func provider(in state: ProviderState) throws -> Provider {
        let provider = Provider(connection: makeConnection())
        switch state {
        case .registered:
            return provider
        case .validated:
            try provider.transition(to: .validated)
        case .initializing:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
        case .ready:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
        case .unavailable:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .unavailable)
        case .disabled:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
            try provider.transition(to: .disabled)
        case .removed:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
            try provider.transition(to: .removed)
        }
        return provider
    }

    func testRoundTrip_PreservesConnectionAndStateInEveryLifecycleState() throws {
        for state in [ProviderState.registered, .validated, .initializing, .ready, .unavailable, .disabled, .removed] {
            let original = try provider(in: state)

            let restored = try serializer.decode(from: serializer.encode(original))

            XCTAssertEqual(restored.connection, original.connection, "connection mismatch for state \(state)")
            XCTAssertEqual(restored.state, state, "state mismatch for state \(state)")
        }
    }

    func testRoundTrip_PreservesDeclaredCapabilities() throws {
        let original = try provider(in: .ready)

        let restored = try serializer.decode(from: serializer.encode(original))

        XCTAssertEqual(restored.connection.capabilities, original.connection.capabilities)
        XCTAssertTrue(restored.canDeliver(.textGeneration))
        XCTAssertTrue(restored.canDeliver(.streaming))
        XCTAssertFalse(restored.canDeliver(.vision))
    }

    func testRoundTrip_RestoredProviderKeepsItsLifecycle() throws {
        let original = try provider(in: .ready)
        let restored = try serializer.decode(from: serializer.encode(original))

        XCTAssertNoThrow(try restored.transition(to: .disabled))
    }

    func testEncode_IsDeterministic() throws {
        let original = try provider(in: .ready)

        XCTAssertEqual(try serializer.encode(original), try serializer.encode(original))
    }

    func testStoredForm_NeverCarriesCredentialMaterial() throws {
        let original = try provider(in: .ready)

        let json = String(data: try serializer.encode(original), encoding: .utf8) ?? ""

        XCTAssertFalse(json.lowercased().contains("secret"))
        XCTAssertFalse(json.lowercased().contains("credential"))
        XCTAssertFalse(json.lowercased().contains("apikey"))
    }

    func testDecode_CorruptDataThrowsStorageUnavailable() {
        XCTAssertThrowsError(try serializer.decode(from: Data("{ not valid json".utf8))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testDecode_UnknownStateThrowsStorageUnavailable() throws {
        let dto = ProviderDTO(
            connection: ProviderConnectionDTO(
                identity: ProviderIdentity(),
                capabilities: ProviderCapabilitiesDTO(capabilities: ["textGeneration"]),
                metadata: ProviderMetadataDTO(displayName: "x"),
                limits: ProviderLimitsDTO(maxRequestsPerMinute: nil, maxTokensPerMinute: nil, maxContextTokens: nil),
                version: SemanticVersionDTO(major: 1, minor: 0, patch: 0)
            ),
            state: "bogus"
        )

        XCTAssertThrowsError(try serializer.decode(from: JSONEncoder().encode(dto))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testDecode_UnknownCapabilityThrowsStorageUnavailable() throws {
        let dto = ProviderDTO(
            connection: ProviderConnectionDTO(
                identity: ProviderIdentity(),
                capabilities: ProviderCapabilitiesDTO(capabilities: ["bogus"]),
                metadata: ProviderMetadataDTO(displayName: "x"),
                limits: ProviderLimitsDTO(maxRequestsPerMinute: nil, maxTokensPerMinute: nil, maxContextTokens: nil),
                version: SemanticVersionDTO(major: 1, minor: 0, patch: 0)
            ),
            state: "ready"
        )

        XCTAssertThrowsError(try serializer.decode(from: JSONEncoder().encode(dto))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
