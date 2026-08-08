import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class ProviderSelectionTests: XCTestCase {

    private func item(
        _ displayName: String = "Alpha",
        state: ProviderState = .ready
    ) -> ProviderConnectionListItem {
        ProviderConnectionListItem(
            identity: ProviderIdentity(),
            displayName: displayName,
            state: state
        )
    }

    // MARK: Creation

    func testCreation_ExposesProvidersSelectedAndFailure() {
        let identity = ProviderIdentity()
        let item = ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection(
            providers: [item],
            selected: identity,
            failure: .unexpected
        )
        XCTAssertEqual(selection.providers, [item])
        XCTAssertEqual(selection.selected, identity)
        XCTAssertEqual(selection.failure, .unexpected)
    }

    func testCreation_DefaultsToNoSelectionAndNoFailure() {
        let item = item("Alpha")
        let selection = ConversationScreenState.ProviderSelection(providers: [item])
        XCTAssertNil(selection.selected)
        XCTAssertNil(selection.failure)
        XCTAssertEqual(selection.providers, [item])
    }

    // MARK: Empty condition

    func testIsEmpty_TrueWithoutProviders() {
        let selection = ConversationScreenState.ProviderSelection(providers: [])
        XCTAssertTrue(selection.isEmpty)
    }

    func testIsEmpty_FalseWithProviders() {
        let selection = ConversationScreenState.ProviderSelection(providers: [item("Alpha")])
        XCTAssertFalse(selection.isEmpty)
    }

    // MARK: Selected item

    func testSelectedItem_ReturnsMatchingProvider() {
        let identity = ProviderIdentity()
        let item = ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection(providers: [item], selected: identity)
        XCTAssertEqual(selection.selectedItem, item)
    }

    func testSelectedItem_NilWhenSelectionNotAmongProviders() {
        let selection = ConversationScreenState.ProviderSelection(
            providers: [item("Alpha")],
            selected: ProviderIdentity()
        )
        XCTAssertNil(selection.selectedItem)
    }

    func testSelectedItem_NilWithoutSelection() {
        let selection = ConversationScreenState.ProviderSelection(providers: [item("Alpha")])
        XCTAssertNil(selection.selectedItem)
    }

    // MARK: Availability

    func testSelectedIsAvailable_TrueWhenSelectedIsReady() {
        let identity = ProviderIdentity()
        let selection = ConversationScreenState.ProviderSelection(
            providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)],
            selected: identity
        )
        XCTAssertTrue(selection.selectedIsAvailable)
    }

    func testSelectedIsAvailable_FalseWhenSelectedIsNotReady() {
        let states: [ProviderState] = [.registered, .validated, .initializing, .unavailable, .disabled, .removed]
        for state in states {
            let identity = ProviderIdentity()
            let selection = ConversationScreenState.ProviderSelection(
                providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: state)],
                selected: identity
            )
            XCTAssertFalse(selection.selectedIsAvailable, "\(state) must not be available")
        }
    }

    func testSelectedIsAvailable_FalseWithoutSelection() {
        let selection = ConversationScreenState.ProviderSelection(providers: [item("Alpha")])
        XCTAssertFalse(selection.selectedIsAvailable)
    }

    func testIsAvailable_TrueOnlyForReady() {
        XCTAssertTrue(ConversationScreenState.ProviderSelection.isAvailable(.ready))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.registered))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.validated))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.initializing))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.unavailable))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.disabled))
        XCTAssertFalse(ConversationScreenState.ProviderSelection.isAvailable(.removed))
    }

    // MARK: Composition

    func testComposed_PassesProvidersAndSelected() {
        let identity = ProviderIdentity()
        let item = ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection.composed(
            providers: [item],
            settingsFailure: .repository(.storageUnavailable),
            selected: identity
        )
        XCTAssertEqual(selection.providers, [item])
        XCTAssertEqual(selection.selected, identity)
        XCTAssertNil(selection.failure, "presented connections keep the settings failure out of scope")
    }

    func testComposed_NoFailureWithEmptyProvidersAndNoSettingsFailure() {
        let selection = ConversationScreenState.ProviderSelection.composed(
            providers: [],
            settingsFailure: nil,
            selected: nil
        )
        XCTAssertTrue(selection.isEmpty)
        XCTAssertNil(selection.failure)
    }

    func testComposed_MapsSettingsFailureWhenProvidersEmpty() {
        let selection = ConversationScreenState.ProviderSelection.composed(
            providers: [],
            settingsFailure: .repository(.storageUnavailable),
            selected: nil
        )
        XCTAssertEqual(selection.failure, .repository(.storageUnavailable))
    }

    func testComposed_MapsEachSettingsFailureType() {
        let application = ConversationScreenState.ProviderSelection.composed(
            providers: [],
            settingsFailure: .application(.invalid(reason: "reason")),
            selected: nil
        )
        XCTAssertEqual(application.failure, .application(.invalid(reason: "reason")))

        let credential = ConversationScreenState.ProviderSelection.composed(
            providers: [],
            settingsFailure: .credentialStorage(.storageUnavailable),
            selected: nil
        )
        XCTAssertEqual(credential.failure, .credentialStorage(.storageUnavailable))
    }

    func testComposed_NormalizesSelectionNotAmongProviders() {
        let selection = ConversationScreenState.ProviderSelection.composed(
            providers: [item("Alpha")],
            settingsFailure: nil,
            selected: ProviderIdentity()
        )
        XCTAssertNil(selection.selected)
    }

    func testComposed_PreservesSelectionWhenSelectedProviderIsUnavailable() {
        let states: [ProviderState] = [.registered, .validated, .initializing, .unavailable, .disabled, .removed]
        for state in states {
            let identity = ProviderIdentity()
            let item = ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: state)
            let selection = ConversationScreenState.ProviderSelection.composed(
                providers: [item],
                settingsFailure: nil,
                selected: identity
            )
            XCTAssertEqual(selection.selectedItem, item, "\(state) must preserve the selected connection")
            XCTAssertFalse(selection.selectedIsAvailable, "\(state) must not be available")
        }
    }

    func testComposed_PreservesSelectionWhenSelectedProviderIsReady() {
        let identity = ProviderIdentity()
        let item = ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection.composed(
            providers: [item],
            settingsFailure: nil,
            selected: identity
        )
        XCTAssertEqual(selection.selectedItem, item)
        XCTAssertTrue(selection.selectedIsAvailable)
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        let identity = ProviderIdentity()
        let a = ConversationScreenState.ProviderSelection(
            providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)],
            selected: identity
        )
        let b = ConversationScreenState.ProviderSelection(
            providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)],
            selected: identity
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentSelectionIsNotEqual() {
        let identity = ProviderIdentity()
        let a = ConversationScreenState.ProviderSelection(
            providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)],
            selected: nil
        )
        let b = ConversationScreenState.ProviderSelection(
            providers: [ProviderConnectionListItem(identity: identity, displayName: "Alpha", state: .ready)],
            selected: identity
        )
        XCTAssertNotEqual(a, b)
    }
}
