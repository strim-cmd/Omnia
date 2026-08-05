import OmniaApplication
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

    func testEquality_DifferentConnectionsAreNotEqual() {
        let a = SettingsState(connections: [connection("A")])
        let b = SettingsState(connections: [connection("B")])
        XCTAssertNotEqual(a, b)
    }
}
