import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class ConversationSerializerTests: XCTestCase {

    private let serializer = ConversationSerializer()

    func testRoundTrip_PreservesEmptyConversation() throws {
        let conversation = Conversation(identity: ConversationIdentity())

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored, conversation)
    }

    func testRoundTrip_PreservesHistoryInOrder() throws {
        var conversation = Conversation(identity: ConversationIdentity())
        let first = Message(role: .system, content: "System prompt")
        let second = Message(role: .user, content: "Hello")
        let third = Message(role: .assistant, content: "Hi there")
        try conversation.append(first)
        try conversation.append(second)
        try conversation.append(third)

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored.history, [first, second, third])
        XCTAssertEqual(restored, conversation)
    }

    func testRoundTrip_PreservesExactProviderModelSelection() throws {
        let selection = ProviderModelSelection(
            provider: ProviderIdentity(),
            model: ModelReference(name: "vendor/model")
        )
        let conversation = Conversation(
            identity: ConversationIdentity(),
            modelSelection: selection
        )

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored.modelSelection, selection)
        XCTAssertEqual(restored, conversation)
    }

    func testDecode_PreV1DocumentWithoutModelSelectionDefaultsToNil() throws {
        let identity = ConversationIdentity()
        let data = Data("""
        {"history":[{"content":"Hello","role":"user"}],"identity":"\(identity.canonicalString)","streamingState":{"state":"idle"}}
        """.utf8)

        let restored = try serializer.decode(from: data)

        XCTAssertEqual(restored.identity, identity)
        XCTAssertEqual(restored.history, [Message(role: .user, content: "Hello")])
        XCTAssertNil(restored.modelSelection)
    }

    func testRoundTrip_PreservesActiveStreamingState() throws {
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("partial")

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored, conversation)
        XCTAssertEqual(restored.streamingState, .streaming(partialContent: "partial"))
    }

    func testRoundTrip_PreservesInterruptedStreamingState() throws {
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.beginStreaming()
        try conversation.appendPartial("kept")
        try conversation.interruptStreaming()

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored, conversation)
        XCTAssertEqual(restored.streamingState, .interrupted(partialContent: "kept"))
    }

    func testRoundTrip_PreservesHistoryAndInterruptedStreamTogether() throws {
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .user, content: "Question"))
        try conversation.beginStreaming()
        try conversation.appendPartial("partial answer")
        try conversation.interruptStreaming()

        let restored = try serializer.decode(from: serializer.encode(conversation))

        XCTAssertEqual(restored, conversation)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.streamingState, .interrupted(partialContent: "partial answer"))
    }

    func testEncode_IsDeterministic() throws {
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .user, content: "Hello"))

        XCTAssertEqual(try serializer.encode(conversation), try serializer.encode(conversation))
    }

    func testDecode_CorruptDataThrowsStorageUnavailable() {
        XCTAssertThrowsError(try serializer.decode(from: Data("{ not valid json".utf8))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testDecode_UnknownRoleThrowsStorageUnavailable() throws {
        let dto = ConversationDTO(
            identity: ConversationIdentity(),
            history: [MessageDTO(role: "hacker", content: "x")],
            streamingState: ConversationStreamingStateDTO(state: "idle", partialContent: nil)
        )

        XCTAssertThrowsError(try serializer.decode(from: JSONEncoder().encode(dto))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testDecode_UnknownStreamingStateThrowsStorageUnavailable() throws {
        let dto = ConversationDTO(
            identity: ConversationIdentity(),
            history: [],
            streamingState: ConversationStreamingStateDTO(state: "bogus", partialContent: nil)
        )

        XCTAssertThrowsError(try serializer.decode(from: JSONEncoder().encode(dto))) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
