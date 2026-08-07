import Foundation
import XCTest
@testable import OmniaFoundation

private let backgroundRefresh = EnvironmentCapability("background-refresh")
private let pushNotifications = EnvironmentCapability("push-notifications")

/// Constructs a deterministic environment from fixed facts.
private func makeEnvironment(
    family: PlatformFamily = .iOS,
    version: SemanticVersion = SemanticVersion(major: 17, minor: 4, patch: 1),
    mode: ExecutionMode = .production,
    capabilities: Set<EnvironmentCapability> = [backgroundRefresh]
) -> Environment {
    Environment(
        platform: Platform(family: family, version: version),
        executionMode: mode,
        capabilities: capabilities
    )
}

/// A consumer that decides behavior from environment facts only.
///
/// It receives the environment by composition and never reads a global or a
/// platform API; replacing the environment changes its answers without
/// changing the consumer.
private struct CapabilityGate {
    private let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    func permits(_ capability: EnvironmentCapability) -> Bool {
        environment.isAvailable(capability)
    }

    func runs(on family: PlatformFamily) -> Bool {
        environment.platform.family == family
    }
}

final class EnvironmentTests: XCTestCase {

    // MARK: Deterministic construction

    func testDeterministicConstruction_SameFactsAlwaysYieldSameValues() {
        let environment = makeEnvironment()
        let repeated = makeEnvironment()
        XCTAssertEqual(environment, repeated)
        XCTAssertEqual(environment.platform.family, .iOS)
        XCTAssertEqual(environment.platform.version, SemanticVersion(major: 17, minor: 4, patch: 1))
        XCTAssertEqual(environment.executionMode, .production)
        XCTAssertEqual(environment.capabilities, [backgroundRefresh])
    }

    func testDeterministicConstruction_DependsOnNoExternalState() {
        let expected = makeEnvironment()
        for _ in 0..<16 {
            XCTAssertEqual(makeEnvironment(), expected)
        }
    }

    // MARK: Platform characteristics

    func testPlatform_ReportsFamilyAndVersion() {
        let environment = makeEnvironment(family: .macOS, version: SemanticVersion(major: 15, minor: 0, patch: 0))
        XCTAssertEqual(environment.platform.family, .macOS)
        XCTAssertEqual(environment.platform.version, SemanticVersion(major: 15, minor: 0, patch: 0))
    }

    func testPlatform_EachFamilyIsDistinct() {
        XCTAssertEqual(PlatformFamily.allCases.count, 3)
        XCTAssertNotEqual(PlatformFamily.iOS, PlatformFamily.iPadOS)
        XCTAssertNotEqual(PlatformFamily.iPadOS, PlatformFamily.macOS)
        XCTAssertNotEqual(PlatformFamily.macOS, PlatformFamily.iOS)
    }

    func testPlatform_VersionIsAComparableValue() {
        let older = makeEnvironment(version: SemanticVersion(major: 16, minor: 0, patch: 0))
        let newer = makeEnvironment(version: SemanticVersion(major: 17, minor: 0, patch: 0))
        XCTAssertLessThan(older.platform.version, newer.platform.version)
    }

    // MARK: Execution mode

    func testExecutionMode_ReportsHowTheProcessIsRunning() {
        XCTAssertEqual(makeEnvironment(mode: .production).executionMode, .production)
        XCTAssertEqual(makeEnvironment(mode: .development).executionMode, .development)
        XCTAssertEqual(makeEnvironment(mode: .preview).executionMode, .preview)
        XCTAssertEqual(makeEnvironment(mode: .tests).executionMode, .tests)
    }

    func testExecutionMode_EachModeIsDistinct() {
        XCTAssertEqual(ExecutionMode.allCases.count, 4)
        for (index, mode) in ExecutionMode.allCases.enumerated() {
            for (otherIndex, other) in ExecutionMode.allCases.enumerated() where index != otherIndex {
                XCTAssertNotEqual(mode, other)
            }
        }
    }

    // MARK: Capabilities

    func testCapabilities_ReportOnlyDeclaredFacts() {
        let environment = makeEnvironment(capabilities: [backgroundRefresh])
        XCTAssertTrue(environment.capabilities.contains(backgroundRefresh))
        XCTAssertFalse(environment.capabilities.contains(pushNotifications))
    }

    func testCapabilities_DuplicatesCollapseIntoSingleFact() {
        let environment = makeEnvironment(capabilities: [backgroundRefresh, backgroundRefresh])
        XCTAssertEqual(environment.capabilities.count, 1)
    }

    // MARK: Feature availability

    func testAvailability_DeclaredCapabilityIsAvailable() {
        let environment = makeEnvironment(capabilities: [backgroundRefresh])
        XCTAssertTrue(environment.isAvailable(backgroundRefresh))
    }

    func testAvailability_UnavailableCapabilityIsNotAvailable() {
        let environment = makeEnvironment(capabilities: [backgroundRefresh])
        XCTAssertFalse(environment.isAvailable(pushNotifications))
    }

    func testAvailability_EmptyCapabilitiesAnswerNo() {
        let environment = makeEnvironment(capabilities: [])
        XCTAssertFalse(environment.isAvailable(backgroundRefresh))
        XCTAssertFalse(environment.isAvailable(pushNotifications))
    }

    func testAvailability_AnswerIsStableAcrossRepeatedReads() {
        let environment = makeEnvironment(capabilities: [backgroundRefresh])
        for _ in 0..<100 {
            XCTAssertTrue(environment.isAvailable(backgroundRefresh))
            XCTAssertFalse(environment.isAvailable(pushNotifications))
        }
    }

    // MARK: Immutability

    func testImmutability_ValuesNeverChangeAcrossRepeatedReads() {
        let environment = makeEnvironment()
        let platform = environment.platform
        let mode = environment.executionMode
        let capabilities = environment.capabilities
        for _ in 0..<16 {
            XCTAssertEqual(environment.platform, platform)
            XCTAssertEqual(environment.executionMode, mode)
            XCTAssertEqual(environment.capabilities, capabilities)
            XCTAssertEqual(environment.isAvailable(backgroundRefresh), true)
        }
    }

    func testImmutability_NoOperationMutatesTheEnvironment() {
        let environment = makeEnvironment()
        let snapshot = environment
        _ = environment.isAvailable(backgroundRefresh)
        _ = environment.platform
        XCTAssertEqual(environment, snapshot)
    }

    // MARK: Equality semantics

    func testEquality_IdenticalValuesAreEqual() {
        XCTAssertEqual(makeEnvironment(), makeEnvironment())
    }

    func testEquality_DifferentPlatformFamilyIsNotEqual() {
        XCTAssertNotEqual(
            makeEnvironment(family: .iOS),
            makeEnvironment(family: .macOS)
        )
    }

    func testEquality_DifferentVersionIsNotEqual() {
        XCTAssertNotEqual(
            makeEnvironment(version: SemanticVersion(major: 17, minor: 0, patch: 0)),
            makeEnvironment(version: SemanticVersion(major: 17, minor: 1, patch: 0))
        )
    }

    func testEquality_DifferentExecutionModeIsNotEqual() {
        XCTAssertNotEqual(
            makeEnvironment(mode: .production),
            makeEnvironment(mode: .preview)
        )
    }

    func testEquality_DifferentCapabilitiesIsNotEqual() {
        XCTAssertNotEqual(
            makeEnvironment(capabilities: [backgroundRefresh]),
            makeEnvironment(capabilities: [pushNotifications])
        )
    }

    func testEquality_CapabilityOrderDoesNotMatter() {
        let a = makeEnvironment(capabilities: [backgroundRefresh, pushNotifications])
        let b = makeEnvironment(capabilities: [pushNotifications, backgroundRefresh])
        XCTAssertEqual(a, b)
    }

    // MARK: Injection

    func testInjection_ConsumerBehavesIdenticallyUnderTestProvidedEnvironment() {
        let gate = CapabilityGate(environment: makeEnvironment(capabilities: [backgroundRefresh]))
        XCTAssertTrue(gate.permits(backgroundRefresh))
        XCTAssertFalse(gate.permits(pushNotifications))
        XCTAssertTrue(gate.runs(on: .iOS))
    }

    func testInjection_EnvironmentIsReplaceableWithoutChangingTheConsumer() {
        let permissive = CapabilityGate(environment: makeEnvironment(capabilities: [backgroundRefresh]))
        let restricted = CapabilityGate(environment: makeEnvironment(capabilities: []))
        XCTAssertTrue(permissive.permits(backgroundRefresh))
        XCTAssertFalse(restricted.permits(backgroundRefresh))
    }

    func testInjection_ConsumerNeverAcquiresByLookup() {
        let gate = CapabilityGate(environment: makeEnvironment(family: .macOS))
        XCTAssertTrue(gate.runs(on: .macOS))
        XCTAssertFalse(gate.runs(on: .iOS))
    }

    // MARK: Predictable behaviour across platforms

    func testPredictableBehaviour_IdenticalFactsBehaveIdenticallyOnAnyPlatform() {
        let ios = CapabilityGate(environment: makeEnvironment(family: .iOS, mode: .tests))
        let macos = CapabilityGate(environment: makeEnvironment(family: .macOS, mode: .tests))
        let ipados = CapabilityGate(environment: makeEnvironment(family: .iPadOS, mode: .tests))
        XCTAssertEqual(ios.permits(backgroundRefresh), true)
        XCTAssertEqual(ios.permits(backgroundRefresh), macos.permits(backgroundRefresh))
        XCTAssertEqual(ios.permits(backgroundRefresh), ipados.permits(backgroundRefresh))
        XCTAssertEqual(ios.permits(pushNotifications), macos.permits(pushNotifications))
    }

    func testPredictableBehaviour_PlatformIsCapturedOnlyAsFacts() {
        let environment = makeEnvironment(family: .iPadOS, mode: .preview)
        let gate = CapabilityGate(environment: environment)
        XCTAssertTrue(gate.runs(on: .iPadOS))
        XCTAssertFalse(gate.runs(on: .macOS))
    }

    // MARK: Value semantics

    func testValueSemantics_EnvironmentsAreImmutableValues() {
        let original = makeEnvironment(capabilities: [backgroundRefresh])
        var copy = original
        copy = makeEnvironment(capabilities: [pushNotifications])
        XCTAssertEqual(original, makeEnvironment(capabilities: [backgroundRefresh]))
        XCTAssertEqual(copy, makeEnvironment(capabilities: [pushNotifications]))
        XCTAssertNotEqual(original, copy)
    }

    // MARK: Sendability and concurrent use

    func testSendability_UsableInSendableClosure() {
        let environment = makeEnvironment()
        let mode = environment.executionMode
        let read: @Sendable () -> ExecutionMode = { environment.executionMode }
        XCTAssertEqual(read(), mode)
    }

    func testConcurrentUse_SharedEnvironmentReadsConsistently() async {
        let environment = makeEnvironment()
        let expected = environment.capabilities
        let reads: [Set<EnvironmentCapability>] = await withTaskGroup(of: Set<EnvironmentCapability>.self) { group in
            for _ in 0..<100 {
                group.addTask { environment.capabilities }
            }
            var collected: [Set<EnvironmentCapability>] = []
            for await read in group {
                collected.append(read)
            }
            return collected
        }
        XCTAssertEqual(reads.count, 100)
        XCTAssertTrue(reads.allSatisfy { $0 == expected })
    }
}
