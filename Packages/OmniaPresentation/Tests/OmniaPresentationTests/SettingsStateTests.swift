import OmniaApplication
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

final class SettingsStateTests: XCTestCase {

    private func connection(_ name: String) -> ProviderConnectionListItem {
        ProviderConnectionListItem(
            identity: ProviderIdentity(),
            displayName: name,
            state: .ready
        )
    }

    private func editing(
        identity: ProviderIdentity = ProviderIdentity(),
        displayName: String = "Example Provider",
        currentEndpoint: String = "https://api.example.com/v1",
        currentModel: String = "omniroute:gpt-4o"
    ) -> SettingsState.Editing {
        SettingsState.Editing(
            identity: identity,
            displayName: displayName,
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .conversation]),
            limits: ProviderLimits(maxRequestsPerMinute: 60),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            currentEndpoint: currentEndpoint,
            currentModel: currentModel
        )
    }

    // MARK: Creation

    func testCreation_ExposesConnections() {
        let connection = self.connection("Test Provider")
        let state = SettingsState(connections: [connection])
        XCTAssertEqual(state.connections, [connection])
        XCTAssertEqual(state.configuration, [])
        XCTAssertFalse(state.isComposing)
        XCTAssertNil(state.failure)
        XCTAssertFalse(state.hasError)
    }

    // MARK: Configuration values

    func testConfiguration_HoldsTypedItems() {
        let item = SettingsState.ConfigurationItem(
            key: ConfigurationKey<String>("model"),
            value: "a-model"
        )
        let state = SettingsState(
            connections: [],
            configuration: [item]
        )
        XCTAssertEqual(state.configuration, [item])
        XCTAssertEqual(state.configuration[0].key, ConfigurationKey<String>("model"))
        XCTAssertEqual(state.configuration[0].value, "a-model")
    }

    // MARK: Compose and error conditions

    func testComposeCondition_ReflectsTheComposeFlow() {
        let state = SettingsState(connections: [], isComposing: true)
        XCTAssertTrue(state.isComposing)
    }

    func testCreation_EditingDefaultsToNil() {
        let state = SettingsState(connections: [])
        XCTAssertNil(state.editing)
    }

    func testEditCondition_ReflectsTheProviderEditFlow() {
        let identity = ProviderIdentity()
        let editing = self.editing(identity: identity)
        let state = SettingsState(connections: [], editing: editing)
        XCTAssertEqual(state.editing, editing)
        XCTAssertEqual(state.editing?.identity, identity)
        XCTAssertEqual(state.editing?.displayName, "Example Provider")
        XCTAssertEqual(
            state.editing?.capabilities,
            ProviderCapabilities(capabilities: [.textGeneration, .conversation])
        )
        XCTAssertEqual(state.editing?.limits, ProviderLimits(maxRequestsPerMinute: 60))
        XCTAssertEqual(state.editing?.version, SemanticVersion(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(state.editing?.currentEndpoint, "https://api.example.com/v1")
        XCTAssertEqual(state.editing?.currentModel, "omniroute:gpt-4o")
    }

    func testEditCondition_EndpointAndModelDefaultToEmptyWhenNoneIsRecorded() {
        let editing = self.editing(currentEndpoint: "", currentModel: "")
        XCTAssertEqual(editing.currentEndpoint, "")
        XCTAssertEqual(editing.currentModel, "")
    }

    func testFailure_ApplicationValidationError() {
        let state = SettingsState(
            connections: [],
            failure: .application(.invalid(reason: "empty name"))
        )
        XCTAssertEqual(state.failure, .application(.invalid(reason: "empty name")))
        XCTAssertTrue(state.hasError)
    }

    func testFailure_RepositoryAndCredentialStorageErrors() {
        let repository = SettingsState(connections: [], failure: .repository(.storageUnavailable))
        XCTAssertEqual(repository.failure, .repository(.storageUnavailable))

        let credential = SettingsState(connections: [], failure: .credentialStorage(.credentialNotFound))
        XCTAssertEqual(credential.failure, .credentialStorage(.credentialNotFound))
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        let connection = self.connection("Test Provider")
        let a = SettingsState(connections: [connection])
        let b = SettingsState(connections: [connection])
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentComposeConditionIsNotEqual() {
        let a = SettingsState(connections: [], isComposing: false)
        let b = SettingsState(connections: [], isComposing: true)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentEditConditionIsNotEqual() {
        let a = SettingsState(connections: [])
        let b = SettingsState(connections: [], editing: self.editing())
        XCTAssertNotEqual(a, b)
    }

    func testEquality_EditingEqualToItself() {
        let editing = self.editing()
        let a = SettingsState(connections: [], editing: editing)
        let b = SettingsState(connections: [], editing: editing)
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentConnectionsAreNotEqual() {
        let a = SettingsState(connections: [connection("A")])
        let b = SettingsState(connections: [connection("B")])
        XCTAssertNotEqual(a, b)
    }
}
