import XCTest
@testable import OmniaDomain

final class CapabilityTests: XCTestCase {

    func testCapabilitySet_DeclaresTheCoreRealizedCapabilities() {
        let core: Set<Capability> = [.textGeneration, .conversation, .streaming]
        XCTAssertEqual(core.count, 3)
        XCTAssertTrue(core.contains(.textGeneration))
        XCTAssertTrue(core.contains(.conversation))
        XCTAssertTrue(core.contains(.streaming))
    }

    func testCapabilitySet_DeclaresTheExtensionPointCapabilities() {
        let extensionPoints: Set<Capability> = [
            .vision,
            .documentInput,
            .imageGeneration,
            .embeddings,
            .toolCalling,
            .structuredOutput,
            .audio,
            .reasoning,
        ]
        XCTAssertEqual(extensionPoints.count, 8)
    }

    func testCapabilitySet_AllCasesAreDistinct() {
        let all: Set<Capability> = [
            .textGeneration, .conversation, .streaming,
            .vision, .documentInput, .imageGeneration, .embeddings,
            .toolCalling, .structuredOutput, .audio, .reasoning,
        ]
        XCTAssertEqual(all.count, 11)
    }

    func testEquality_SameCaseIsEqual() {
        XCTAssertEqual(Capability.textGeneration, .textGeneration)
        XCTAssertEqual(Capability.streaming, .streaming)
    }

    func testEquality_DifferentCasesAreNotEqual() {
        XCTAssertNotEqual(Capability.textGeneration, .streaming)
        XCTAssertNotEqual(Capability.conversation, .embeddings)
    }

    func testHashability_EqualCapabilitiesHashEqually() {
        XCTAssertEqual(Capability.reasoning.hashValue, Capability.reasoning.hashValue)
    }
}
