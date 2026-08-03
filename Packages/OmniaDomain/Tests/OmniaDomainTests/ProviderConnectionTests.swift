import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalProviderA = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalProviderB = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private func makeProviderConnection(
    identity: ProviderIdentity = ProviderIdentity(),
    capabilities: ProviderCapabilities = ProviderCapabilities(
        capabilities: [.textGeneration, .conversation, .streaming]
    ),
    metadata: ProviderMetadata = ProviderMetadata(displayName: "Mock Provider"),
    limits: ProviderLimits = ProviderLimits(maxRequestsPerMinute: 60),
    version: SemanticVersion = SemanticVersion(major: 1, minor: 0, patch: 0)
) -> ProviderConnection {
    ProviderConnection(
        identity: identity,
        capabilities: capabilities,
        metadata: metadata,
        limits: limits,
        version: version
    )
}

final class ProviderConnectionTests: XCTestCase {

    // MARK: Creation

    func testCreation_RetainsIdentityCapabilitiesMetadataLimitsAndVersion() throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let capabilities = ProviderCapabilities(capabilities: [.textGeneration, .streaming])
        let metadata = ProviderMetadata(displayName: "OpenAI Compatible")
        let limits = ProviderLimits(maxTokensPerMinute: 60_000)
        let version = SemanticVersion(major: 1, minor: 2, patch: 0)

        let provider = ProviderConnection(
            identity: identity,
            capabilities: capabilities,
            metadata: metadata,
            limits: limits,
            version: version
        )

        XCTAssertEqual(provider.identity, identity)
        XCTAssertEqual(provider.capabilities, capabilities)
        XCTAssertEqual(provider.metadata, metadata)
        XCTAssertEqual(provider.limits, limits)
        XCTAssertEqual(provider.version, version)
    }

    func testCreation_ModelCarriesDeclaredCapabilitiesOnly() {
        let provider = makeProviderConnection(capabilities: ProviderCapabilities(capabilities: [.textGeneration]))
        XCTAssertTrue(provider.capabilities.contains(.textGeneration))
        XCTAssertFalse(provider.capabilities.contains(.vision))
        XCTAssertFalse(provider.capabilities.contains(.embeddings))
    }

    // MARK: Equality

    func testEquality_ContentEqualIsEqual() throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        XCTAssertEqual(makeProviderConnection(identity: identity), makeProviderConnection(identity: identity))
    }

    func testEquality_DifferentIdentityIsNotEqual() throws {
        let a = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let b = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderB))
        XCTAssertNotEqual(makeProviderConnection(identity: a), makeProviderConnection(identity: b))
    }

    func testEquality_DifferentCapabilitiesIsNotEqual() throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let base = makeProviderConnection(identity: identity)
        let other = makeProviderConnection(
            identity: identity,
            capabilities: ProviderCapabilities(capabilities: [.textGeneration])
        )
        XCTAssertNotEqual(base, other)
    }

    func testEquality_DifferentVersionIsNotEqual() throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let base = makeProviderConnection(identity: identity)
        let other = makeProviderConnection(identity: identity, version: SemanticVersion(major: 2, minor: 0, patch: 0))
        XCTAssertNotEqual(base, other)
    }

    // MARK: Sendability

    func testSendability_UsableInSendableClosure() throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let provider = makeProviderConnection(identity: identity)
        let version = provider.version
        let read: @Sendable () -> SemanticVersion = { provider.version }
        XCTAssertEqual(read(), version)
    }

    func testSendability_ShareProviderAcrossConcurrencyDomain() async throws {
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let provider = makeProviderConnection(identity: identity)
        let returned = await Task.detached {
            provider.identity
        }.value
        XCTAssertEqual(returned, identity)
    }
}
