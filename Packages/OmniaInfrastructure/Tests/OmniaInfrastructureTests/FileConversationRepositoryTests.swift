import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class FileConversationRepositoryTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileConversationRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    private func makeRepository() -> FileConversationRepository {
        FileConversationRepository(directory: directoryURL)
    }

    // MARK: - Save / Load round-trip

    func testSaveThenLoad_RoundTripsAnEmptyConversation() async throws {
        let repository = makeRepository()
        let conversation = Conversation(identity: ConversationIdentity())

        try await repository.save(conversation)
        let loaded = try await repository.conversation(with: conversation.identity)

        XCTAssertEqual(loaded, conversation)
    }

    func testSaveThenLoad_PreservesFullHistoryInOrder() async throws {
        let repository = makeRepository()
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .system, content: "System prompt"))
        try conversation.append(Message(role: .user, content: "Hello"))
        try conversation.append(Message(role: .assistant, content: "Hi there"))

        try await repository.save(conversation)
        let loaded = try await repository.conversation(with: conversation.identity)

        XCTAssertEqual(loaded, conversation)
        XCTAssertEqual(loaded?.history, conversation.history)
    }

    func testSaveThenLoad_PreservesStreamingState() async throws {
        let repository = makeRepository()
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .user, content: "Question"))
        try conversation.beginStreaming()
        try conversation.appendPartial("partial answer")
        try conversation.interruptStreaming()

        try await repository.save(conversation)
        let loaded = try await repository.conversation(with: conversation.identity)

        XCTAssertEqual(loaded, conversation)
        XCTAssertEqual(loaded?.streamingState, .interrupted(partialContent: "partial answer"))
    }

    func testSave_ReplacesExistingConversationWithSameIdentity() async throws {
        let repository = makeRepository()
        let identity = ConversationIdentity()
        var first = Conversation(identity: identity)
        try first.append(Message(role: .user, content: "First"))
        var second = Conversation(identity: identity)
        try second.append(Message(role: .user, content: "Second"))

        try await repository.save(first)
        try await repository.save(second)

        let loaded = try await repository.conversation(with: identity)
        XCTAssertEqual(loaded, second)
    }

    // MARK: - Load absent

    func testConversation_WithAbsentIdentityReturnsNil() async throws {
        let repository = makeRepository()

        let loaded = try await repository.conversation(with: ConversationIdentity())

        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func testDelete_RemovesTheConversation() async throws {
        let repository = makeRepository()
        let conversation = Conversation(identity: ConversationIdentity())

        try await repository.save(conversation)
        try await repository.delete(conversation.identity)

        let loaded = try await repository.conversation(with: conversation.identity)
        XCTAssertNil(loaded)
    }

    func testDelete_AbsentIdentityIsNotAnError() async throws {
        let repository = makeRepository()

        try await repository.delete(ConversationIdentity())
    }

    func testDelete_IsIdempotent() async throws {
        let repository = makeRepository()
        let conversation = Conversation(identity: ConversationIdentity())

        try await repository.save(conversation)
        try await repository.delete(conversation.identity)
        try await repository.delete(conversation.identity)
    }

    // MARK: - Storage-error translation

    func testSave_WhenDirectoryCannotBeReached_ThrowsStorageUnavailable() async throws {
        let blockingFileURL = directoryURL.appendingPathComponent("blocking-file")
        try Data("not a directory".utf8).write(to: blockingFileURL)
        let repository = FileConversationRepository(directory: blockingFileURL)

        do {
            try await repository.save(Conversation(identity: ConversationIdentity()))
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testConversation_WithCorruptedStoredDocument_ThrowsStorageUnavailable() async throws {
        let repository = makeRepository()
        let identity = ConversationIdentity()
        let badRoleDocument = Data(
            """
            {"identity":"\(identity.canonicalString)","history":[{"role":"admin","content":"x"}],"streamingState":{"state":"idle","partialContent":null}}
            """.utf8
        )
        try badRoleDocument.write(
            to: directoryURL
                .appendingPathComponent(identity.canonicalString)
                .appendingPathExtension("json")
        )

        do {
            _ = try await repository.conversation(with: identity)
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
