import XCTest
@testable import OmniaDomain

private struct MockTextGeneration: TextGenerationContract {}

private struct MockConversation: ConversationContract {}

private struct MockStreaming: StreamingContract {}

private struct MockMultiCapability: TextGenerationContract, ConversationContract, StreamingContract {}

final class CapabilityContractTests: XCTestCase {

    // MARK: Realized contracts

    func testRealizedContracts_ConformToTheCapabilityContract() {
        let contracts: [any CapabilityContract] = [
            MockTextGeneration(),
            MockConversation(),
            MockStreaming(),
        ]
        XCTAssertEqual(contracts.count, 3)
        XCTAssertTrue(contracts[0] is TextGenerationContract)
        XCTAssertTrue(contracts[1] is ConversationContract)
        XCTAssertTrue(contracts[2] is StreamingContract)
    }

    func testMultiCapabilityConformance_OneTypeDeliversMultipleCapabilities() {
        let contract: any CapabilityContract = MockMultiCapability()
        XCTAssertTrue(contract is TextGenerationContract)
        XCTAssertTrue(contract is ConversationContract)
        XCTAssertTrue(contract is StreamingContract)
    }

    // MARK: Realized set

    func testRealizedSet_ContainsExactlyTheCoreCapabilities() {
        XCTAssertEqual(Capability.realized, [.textGeneration, .conversation, .streaming])
        XCTAssertEqual(Capability.realized.count, 3)
    }

    func testRealizedSet_ExcludesExtensionPoints() {
        let extensionPoints: Set<Capability> = [
            .vision,
            .imageGeneration,
            .embeddings,
            .toolCalling,
            .structuredOutput,
            .audio,
            .reasoning,
        ]
        XCTAssertTrue(Capability.realized.isDisjoint(with: extensionPoints))
    }

    func testRealizedSet_MatchesTheNumberOFRealizedContracts() {
        XCTAssertEqual(Capability.realized.count, 3)
    }

    // MARK: Sendability

    func testSendability_ShareContractAcrossConcurrencyDomain() async {
        let contract = MockMultiCapability()
        let isConversation: Bool = await Task.detached {
            (contract as any CapabilityContract) is ConversationContract
        }.value
        XCTAssertTrue(isConversation)
    }
}
