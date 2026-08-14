import XCTest
@testable import OmniaDomain

private let canonicalSmallest = "00000000-0000-0000-0000-000000000000"
private let canonicalLargest = "11111111-1111-1111-1111-111111111111"

private func provider(_ canonical: String) throws -> ProviderIdentity {
    try XCTUnwrap(ProviderIdentity(restoring: canonical))
}

private func candidate(
    _ canonical: String,
    models: [String] = ["model"]
) throws -> ProviderCandidate {
    let identity = try provider(canonical)
    return ProviderCandidate(provider: identity, models: models.map { ModelReference(name: $0) })
}

private let policy = ProviderSelectionPolicy()

final class ProviderSelectionPolicyTests: XCTestCase {

    func testUserSelection_WinsOverWorkspaceAndCapabilityPreferences() throws {
        let user = try candidate(canonicalSmallest)
        let workspace = try candidate(canonicalLargest)

        let result = policy.select(
            candidates: [user, workspace],
            userSelection: user.provider,
            workspacePreference: workspace.provider,
            capabilityPreference: workspace.provider
        )

        XCTAssertEqual(result, .selected(provider: user.provider, model: ModelReference(name: "model")))
    }

    func testWorkspacePreference_UsedWhenNoUserSelection() throws {
        let workspace = try candidate(canonicalLargest)
        let capability = try candidate(canonicalSmallest)

        let result = policy.select(
            candidates: [workspace, capability],
            userSelection: nil,
            workspacePreference: workspace.provider,
            capabilityPreference: capability.provider
        )

        XCTAssertEqual(result, .selected(provider: workspace.provider, model: ModelReference(name: "model")))
    }

    func testCapabilityPreference_UsedWhenNoUserOrWorkspaceSelection() throws {
        let capability = try candidate(canonicalSmallest)
        let other = try candidate(canonicalLargest)

        let result = policy.select(
            candidates: [capability, other],
            userSelection: nil,
            workspacePreference: nil,
            capabilityPreference: capability.provider
        )

        XCTAssertEqual(result, .selected(provider: capability.provider, model: ModelReference(name: "model")))
    }

    func testAutomaticSelection_IsDeterministicByIdentityOrder() throws {
        let larger = try candidate(canonicalLargest)
        let smaller = try candidate(canonicalSmallest)

        let result = policy.select(
            candidates: [larger, smaller],
            userSelection: nil,
            workspacePreference: nil,
            capabilityPreference: nil
        )

        XCTAssertEqual(result, .selected(provider: smaller.provider, model: ModelReference(name: "model")))
    }

    func testUserSelection_ToNonCandidateFallsThroughToWorkspacePreference() throws {
        let userChoice = try provider(canonicalLargest)
        let workspace = try candidate(canonicalSmallest)

        let result = policy.select(
            candidates: [workspace],
            userSelection: userChoice,
            workspacePreference: workspace.provider,
            capabilityPreference: nil
        )

        XCTAssertEqual(result, .selected(provider: workspace.provider, model: ModelReference(name: "model")))
    }

    func testUserSelection_ToCandidateWithoutModelsFallsThrough() throws {
        let withoutModels = try candidate(canonicalSmallest, models: [])
        let automatic = try candidate(canonicalLargest)

        let result = policy.select(
            candidates: [withoutModels, automatic],
            userSelection: withoutModels.provider,
            workspacePreference: nil,
            capabilityPreference: nil
        )

        XCTAssertEqual(result, .selected(provider: automatic.provider, model: ModelReference(name: "model")))
    }

    func testFailure_WhenNoCandidates() {
        let result = policy.select(
            candidates: [],
            userSelection: nil,
            workspacePreference: nil,
            capabilityPreference: nil
        )
        XCTAssertEqual(result, .failure)
    }

    func testFailure_WhenEveryCandidateLacksModels() throws {
        let withoutModels = try candidate(canonicalSmallest, models: [])
        let result = policy.select(
            candidates: [withoutModels],
            userSelection: nil,
            workspacePreference: nil,
            capabilityPreference: nil
        )
        XCTAssertEqual(result, .failure)
    }

    func testFailure_NeverSelectsAProviderThatCannotDeliver() throws {
        let workspace = try provider(canonicalLargest)
        let result = policy.select(
            candidates: [],
            userSelection: nil,
            workspacePreference: workspace,
            capabilityPreference: nil
        )
        XCTAssertEqual(result, .failure)
    }

    func testExactSelectionIsStableAcrossCandidateAndModelReordering() throws {
        let selectedProvider = try provider(canonicalLargest)
        let exact = ProviderModelSelection(
            provider: selectedProvider,
            model: ModelReference(name: "model-b")
        )
        let firstOrder = [
            try candidate(canonicalLargest, models: ["model-a", "model-b"]),
            try candidate(canonicalSmallest, models: ["model-b"]),
        ]
        let secondOrder = [
            try candidate(canonicalSmallest, models: ["model-b"]),
            try candidate(canonicalLargest, models: ["model-b", "model-a"]),
        ]

        XCTAssertEqual(
            policy.select(candidates: firstOrder, explicitSelection: exact),
            .selected(provider: selectedProvider, model: exact.model)
        )
        XCTAssertEqual(
            policy.select(candidates: secondOrder, explicitSelection: exact),
            .selected(provider: selectedProvider, model: exact.model)
        )
    }

    func testUnavailableExactSelectionNeverFallsBack() throws {
        let exact = ProviderModelSelection(
            provider: try provider(canonicalLargest),
            model: ModelReference(name: "removed-model")
        )
        let result = policy.select(
            candidates: [try candidate(canonicalSmallest, models: ["available-model"])],
            explicitSelection: exact
        )

        XCTAssertEqual(result, .modelUnavailable(exact))
    }
}
