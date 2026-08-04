import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalProviderA = "550E8400-E29B-41D4-A716-446655440000"

private func makeConnection(
    identity: ProviderIdentity = ProviderIdentity(),
    capabilities: Set<Capability> = [.textGeneration]
) -> ProviderConnection {
    ProviderConnection(
        identity: identity,
        capabilities: ProviderCapabilities(capabilities: capabilities),
        metadata: ProviderMetadata(displayName: "Mock Provider"),
        limits: ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion(major: 1, minor: 0, patch: 0)
    )
}

private func makeReady(service: ProviderLifecycleService, identity: ProviderIdentity) async throws {
    try await service.transition(identity, to: .validated)
    try await service.transition(identity, to: .initializing)
    try await service.transition(identity, to: .ready)
}

final class ProviderLifecycleServiceTests: XCTestCase {

    func testRegister_AddsProviderInRegisteredState() async {
        let service = ProviderLifecycleService()
        let identity = await service.register(makeConnection())

        let state = await service.state(of: identity)
        XCTAssertEqual(state, .registered)
    }

    func testRegister_ReturnsTheRegisteredIdentity() async {
        let service = ProviderLifecycleService()
        let identity = await service.register(makeConnection())
        let provider = await service.provider(with: identity)
        XCTAssertEqual(provider?.identity, identity)
    }

    func testRegister_ReplacesTheProviderWithTheSameIdentity() async throws {
        let service = ProviderLifecycleService()
        let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProviderA))
        let replaced = ProviderConnection(
            identity: identity,
            capabilities: ProviderCapabilities(capabilities: [.streaming]),
            metadata: ProviderMetadata(displayName: "Replaced"),
            limits: ProviderLimits(maxRequestsPerMinute: 60),
            version: SemanticVersion(major: 1, minor: 0, patch: 0)
        )
        await service.register(replaced)
        await service.register(makeConnection(identity: identity))

        let provider = await service.provider(with: identity)
        XCTAssertEqual(provider?.connection.metadata, ProviderMetadata(displayName: "Mock Provider"))
    }

    func testTransition_LegalChainToReady() async throws {
        let service = ProviderLifecycleService()
        let identity = await service.register(makeConnection())

        try await service.transition(identity, to: .validated)
        try await service.transition(identity, to: .initializing)
        try await service.transition(identity, to: .ready)

        let state = await service.state(of: identity)
        XCTAssertEqual(state, .ready)
    }

    func testTransition_IllegalTransitionIsRejectedWithTypedFailure() async throws {
        let service = ProviderLifecycleService()
        let identity = await service.register(makeConnection())

        do {
            try await service.transition(identity, to: .ready)
            XCTFail("Expected an invalid transition failure")
        } catch let error as ProviderLifecycleError {
            XCTAssertEqual(error, .invalidTransition(from: .registered, to: .ready))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = await service.state(of: identity)
        XCTAssertEqual(state, .registered)
    }

    func testTransition_UnknownProviderIsRejected() async {
        let service = ProviderLifecycleService()
        let identity = ProviderIdentity()

        do {
            try await service.transition(identity, to: .validated)
            XCTFail("Expected a provider-not-found failure")
        } catch let error as ProviderLifecycleError {
            XCTAssertEqual(error, .providerNotFound(identity: identity))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProvidersReadyCapableOf_ReturnsOnlyReadyCapableProviders() async throws {
        let service = ProviderLifecycleService()
        let readyCapable = ProviderIdentity()
        let readyIncapable = ProviderIdentity()
        let registeredOnly = ProviderIdentity()

        await service.register(makeConnection(identity: readyCapable, capabilities: [.textGeneration]))
        await service.register(makeConnection(identity: readyIncapable, capabilities: [.streaming]))
        await service.register(makeConnection(identity: registeredOnly, capabilities: [.textGeneration]))
        try await makeReady(service: service, identity: readyCapable)
        try await makeReady(service: service, identity: readyIncapable)

        let ready = await service.providersReady(capableOf: .textGeneration)

        XCTAssertEqual(ready, [readyCapable])
        XCTAssertFalse(ready.contains(readyIncapable))
        XCTAssertFalse(ready.contains(registeredOnly))
    }

    func testAllProviders_ReturnsEveryRegisteredIdentity() async {
        let service = ProviderLifecycleService()
        let a = await service.register(makeConnection())
        let b = await service.register(makeConnection())
        let all = await service.allProviders()
        XCTAssertEqual(Set(all), Set([a, b]))
    }
}
