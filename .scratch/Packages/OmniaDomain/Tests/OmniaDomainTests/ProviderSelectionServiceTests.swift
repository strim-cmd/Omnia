import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalSmallest = "00000000-0000-0000-0000-000000000000"
private let canonicalLargest = "11111111-1111-1111-1111-111111111111"

private func makeConnection(
    identity: ProviderIdentity,
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

private func makeService(
    modelsByProvider: [String: [ModelReference]],
    capabilities: Set<Capability> = [.textGeneration]
) async -> (ProviderSelectionService, ProviderLifecycleService, [String: ProviderIdentity]) {
    let lifecycle = ProviderLifecycleService()
    let smallest = try! XCTUnwrap(ProviderIdentity(restoring: canonicalSmallest))
    let largest = try! XCTUnwrap(ProviderIdentity(restoring: canonicalLargest))
    await lifecycle.register(makeConnection(identity: smallest, capabilities: capabilities))
    await lifecycle.register(makeConnection(identity: largest, capabilities: capabilities))
    try! await lifecycle.transition(smallest, to: .validated)
    try! await lifecycle.transition(smallest, to: .initializing)
    try! await lifecycle.transition(smallest, to: .ready)
    try! await lifecycle.transition(largest, to: .validated)
    try! await lifecycle.transition(largest, to: .initializing)
    try! await lifecycle.transition(largest, to: .ready)

    let service = ProviderSelectionService(
        lifecycleService: lifecycle,
        preferredModels: { identity in
            modelsByProvider[identity.canonicalString] ?? []
        }
    )
    let identities = [
        canonicalSmallest: smallest,
        canonicalLargest: largest,
    ]
    return (service, lifecycle, identities)
}

final class ProviderSelectionServiceTests: XCTestCase {

    func testSelect_HonorsUserSelectionWithItsModel() async throws {
        let (service, _, identities) = await makeService(modelsByProvider: [
            canonicalSmallest: [ModelReference(name: "model-small")],
            canonicalLargest: [ModelReference(name: "model-large")],
        ])
        let user = try XCTUnwrap(identities[canonicalLargest])

        let result = await service.select(
            requiredCapability: .textGeneration,
            userSelection: user
        )

        XCTAssertEqual(
            result,
            .selected(provider: user, model: ModelReference(name: "model-large"))
        )
    }

    func testSelect_FallsToAutomaticSelectionDeterministically() async throws {
        let (service, _, identities) = await makeService(modelsByProvider: [
            canonicalSmallest: [ModelReference(name: "model-small")],
            canonicalLargest: [ModelReference(name: "model-large")],
        ])
        let smallest = try XCTUnwrap(identities[canonicalSmallest])

        let result = await service.select(requiredCapability: .textGeneration)

        XCTAssertEqual(
            result,
            .selected(provider: smallest, model: ModelReference(name: "model-small"))
        )
    }

    func testSelect_FailureWhenNothingReadyCanDeliver() async throws {
        let (service, _, identities) = await makeService(
            modelsByProvider: [
                canonicalSmallest: [ModelReference(name: "model-small")],
                canonicalLargest: [ModelReference(name: "model-large")],
            ],
            capabilities: [.streaming]
        )
        _ = try XCTUnwrap(identities[canonicalSmallest])

        let result = await service.select(requiredCapability: .vision)

        XCTAssertEqual(result, .failure)
    }

    func testSelect_FailureWhenSelectedProviderCannotDeliver() async throws {
        let (service, _, identities) = await makeService(
            modelsByProvider: [
                canonicalSmallest: [ModelReference(name: "model-small")],
                canonicalLargest: [ModelReference(name: "model-large")],
            ],
            capabilities: [.streaming]
        )
        let user = try XCTUnwrap(identities[canonicalSmallest])

        let result = await service.select(requiredCapability: .textGeneration, userSelection: user)

        XCTAssertEqual(result, .failure)
    }

    func testSelect_FailureWhenCandidateHasNoModels() async throws {
        let (service, _, _) = await makeService(modelsByProvider: [:])

        let result = await service.select(requiredCapability: .textGeneration)

        XCTAssertEqual(result, .failure)
    }

    func testSelect_HonorsWorkspacePreference() async throws {
        let (service, _, identities) = await makeService(modelsByProvider: [
            canonicalSmallest: [ModelReference(name: "model-small")],
            canonicalLargest: [ModelReference(name: "model-large")],
        ])
        let largest = try XCTUnwrap(identities[canonicalLargest])

        let result = await service.select(
            requiredCapability: .textGeneration,
            workspacePreference: largest
        )

        XCTAssertEqual(
            result,
            .selected(provider: largest, model: ModelReference(name: "model-large"))
        )
    }
}
