import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalProvider = "1CE9122D-9DDE-11D1-80B4-00C04FD430C8"

private final class RecordingObserver: LifecycleObserver, @unchecked Sendable {
    typealias State = ProviderState
    private var events: [LifecycleEvent<ProviderState>] = []
    private let lock = NSLock()

    func lifecycleDidTransition(_ event: LifecycleEvent<ProviderState>) {
        lock.withLock {
            events.append(event)
        }
    }

    func recordedEvents() -> [LifecycleEvent<ProviderState>] {
        lock.withLock {
            events
        }
    }
}

private func makeConnection(
    capabilities: ProviderCapabilities = ProviderCapabilities(capabilities: [.textGeneration])
) throws -> ProviderConnection {
    let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))
    return ProviderConnection(
        identity: identity,
        capabilities: capabilities,
        metadata: ProviderMetadata(displayName: "Mock Provider"),
        limits: ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion(major: 1, minor: 0, patch: 0)
    )
}

final class ProviderTests: XCTestCase {

    // MARK: Creation

    func testCreation_StartsRegistered() throws {
        let connection = try makeConnection()
        let provider = Provider(connection: connection)
        XCTAssertEqual(provider.state, .registered)
        XCTAssertEqual(provider.identity, connection.identity)
    }

    func testCanDeliver_ReflectsDeclaredCapabilities() throws {
        let connection = try makeConnection(
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .conversation])
        )
        let provider = Provider(connection: connection)

        XCTAssertTrue(provider.canDeliver(.textGeneration))
        XCTAssertTrue(provider.canDeliver(.conversation))
        XCTAssertFalse(provider.canDeliver(.streaming))
    }

    func testConnectionDataIsImmutable() throws {
        let connection = try makeConnection()
        let provider = Provider(connection: connection)
        XCTAssertEqual(provider.connection, connection)
    }

    // MARK: Legal transitions

    func testLegalChain_RegisteredToReady() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        XCTAssertEqual(provider.state, .ready)
    }

    func testLegalChain_ReadyToUnavailableToDisabled() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .unavailable)
        try provider.transition(to: .disabled)
        XCTAssertEqual(provider.state, .disabled)
    }

    func testLegalChain_DisabledBackToReady() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .unavailable)
        try provider.transition(to: .disabled)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        XCTAssertEqual(provider.state, .ready)
    }

    func testLegalTransition_ToRemoved() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .removed)
        XCTAssertEqual(provider.state, .removed)
    }

    // MARK: Illegal transitions are rejected

    func testIllegalTransition_SkipsIntermediateStates() throws {
        let provider = Provider(connection: try makeConnection())
        XCTAssertThrowsError(try provider.transition(to: .ready)) { error in
            XCTAssertEqual(
                error as? ProviderLifecycleError,
                .invalidTransition(from: .registered, to: .ready)
            )
        }
        XCTAssertEqual(provider.state, .registered)
    }

    func testIllegalTransition_FromRegisteredToDisabled() throws {
        let provider = Provider(connection: try makeConnection())
        XCTAssertThrowsError(try provider.transition(to: .disabled)) { error in
            XCTAssertEqual(
                error as? ProviderLifecycleError,
                .invalidTransition(from: .registered, to: .disabled)
            )
        }
        XCTAssertEqual(provider.state, .registered)
    }

    func testIllegalTransition_RemovedIsTerminal() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .removed)

        XCTAssertThrowsError(try provider.transition(to: .registered)) { error in
            XCTAssertEqual(
                error as? ProviderLifecycleError,
                .invalidTransition(from: .removed, to: .registered)
            )
        }
        XCTAssertEqual(provider.state, .removed)
    }

    func testIllegalTransition_UnavailableToReady() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .unavailable)

        XCTAssertThrowsError(try provider.transition(to: .ready)) { error in
            XCTAssertEqual(
                error as? ProviderLifecycleError,
                .invalidTransition(from: .unavailable, to: .ready)
            )
        }
        XCTAssertEqual(provider.state, .unavailable)
    }

    // MARK: Observation

    func testObserver_ReceivesEachLegalTransition() throws {
        let observer = RecordingObserver()
        let provider = Provider(connection: try makeConnection())
        provider.addObserver(observer)

        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)

        XCTAssertEqual(
            observer.recordedEvents(),
            [
                LifecycleEvent(previousState: .registered, newState: .validated),
                LifecycleEvent(previousState: .validated, newState: .initializing),
            ]
        )
    }

    func testObserver_ReceivesNoEventForRejectedTransition() throws {
        let observer = RecordingObserver()
        let provider = Provider(connection: try makeConnection())
        provider.addObserver(observer)

        XCTAssertThrowsError(try provider.transition(to: .ready))

        XCTAssertTrue(observer.recordedEvents().isEmpty)
    }

    func testObserver_ObservesOneWayWithoutAlteringTransitions() throws {
        let provider = Provider(connection: try makeConnection())
        let observer = RecordingObserver()
        provider.addObserver(observer)

        try provider.transition(to: .validated)

        XCTAssertEqual(provider.state, .validated)
        XCTAssertEqual(
            observer.recordedEvents(),
            [LifecycleEvent(previousState: .registered, newState: .validated)]
        )
    }

    // MARK: Replacing the connection

    func testReplacingConnection_PreservesLifecycleStateAndCarriesNewDeclaration() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)

        let updated = provider.replacingConnection(
            ProviderConnection(
                identity: provider.identity,
                capabilities: ProviderCapabilities(capabilities: [.streaming]),
                metadata: ProviderMetadata(displayName: "Edited"),
                limits: ProviderLimits(maxRequestsPerMinute: 30),
                version: SemanticVersion(major: 2, minor: 0, patch: 0)
            )
        )

        XCTAssertEqual(updated.state, .ready)
        XCTAssertEqual(updated.identity, provider.identity)
        XCTAssertEqual(updated.connection.metadata, ProviderMetadata(displayName: "Edited"))
        XCTAssertEqual(
            updated.connection.capabilities,
            ProviderCapabilities(capabilities: [.streaming])
        )
    }

    func testReplacingConnection_DoesNotCarryObservers() throws {
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        let observer = RecordingObserver()
        provider.addObserver(observer)

        let updated = provider.replacingConnection(
            ProviderConnection(
                identity: provider.identity,
                capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
                metadata: ProviderMetadata(displayName: "Edited"),
                limits: ProviderLimits(maxRequestsPerMinute: 60),
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        )
        try updated.transition(to: .unavailable)

        XCTAssertEqual(updated.state, .unavailable)
        XCTAssertTrue(observer.recordedEvents().isEmpty)
    }
}
