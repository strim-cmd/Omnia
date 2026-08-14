import Foundation
import OmniaApplication
import OmniaDomain
import OmniaInfrastructure
import XCTest
@testable import OmniaApp

final class AttachmentCompositionTests: XCTestCase {
    func testPrepareRemovesUnreferencedStagedFiles() async throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = CompositionRoot(storageRoot: rootURL)
        _ = try await root.prepare()
        let attachment = try await stageText(using: root)
        let file = attachmentFile(attachment, root: rootURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        _ = try await root.prepare()

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testRelaunchPreservesMetadataAndOwnedFileWithoutDuplicates() async throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let firstRoot = CompositionRoot(storageRoot: rootURL)
        _ = try await firstRoot.prepare()
        let attachment = try await stageText(using: firstRoot)
        let repository = FileConversationRepository(
            directory: rootURL.appendingPathComponent("Conversations")
        )
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(
            Message(role: .user, content: "Read", attachments: [attachment])
        )
        try await repository.save(conversation)

        let relaunched = CompositionRoot(storageRoot: rootURL)
        _ = try await relaunched.prepare()
        let conversations = try await repository.allConversations()

        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations[0].history.count, 1)
        XCTAssertEqual(conversations[0].history[0].attachments, [attachment])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: attachmentFile(attachment, root: rootURL).path
            )
        )
    }

    func testConversationDeletionRemovesOnlyTheLastReference() async throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = CompositionRoot(storageRoot: rootURL)
        _ = try await root.prepare()
        let attachment = try await stageText(using: root)
        let repository = FileConversationRepository(
            directory: rootURL.appendingPathComponent("Conversations")
        )
        var first = Conversation(identity: ConversationIdentity())
        var second = Conversation(identity: ConversationIdentity())
        let message = Message(role: .user, content: "Shared", attachments: [attachment])
        try first.append(message)
        try second.append(message)
        try await repository.save(first)
        try await repository.save(second)
        let file = attachmentFile(attachment, root: rootURL)

        try await root.conversationService.delete(first.identity)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        let remainingConversation = try await repository.conversation(with: second.identity)
        XCTAssertEqual(
            remainingConversation?.history.first?.attachments,
            [attachment]
        )

        try await root.conversationService.delete(second.identity)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testPhotoSelectionCreatesPendingCanonicalImageAttachment() async throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = CompositionRoot(storageRoot: rootURL)
        _ = try await root.prepare()

        let staged = try await root.attachmentService.stage(
            [
                PhotoAttachmentImport.candidate(
                    data: Data([0xFF, 0xD8, 0xFF, 0x00]),
                    selectionIndex: 0,
                    declaredMediaType: "image/jpeg",
                    preferredFilenameExtension: "jpeg"
                ),
            ],
            existing: []
        )

        XCTAssertEqual(staged.count, 1)
        XCTAssertEqual(staged[0].fileName, "Photo-1.jpg")
        XCTAssertEqual(staged[0].mediaType, "image/jpeg")
        XCTAssertEqual(staged[0].kind, .image)
        XCTAssertEqual(staged[0].byteCount, 4)
        XCTAssertFalse(staged[0].storageKey.isEmpty)
    }

    func testPhotoAndFileSelectedJPGHaveEquivalentCapabilityClassification() async throws {
        let rootURL = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = CompositionRoot(storageRoot: rootURL)
        _ = try await root.prepare()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x00])
        let fileURL = rootURL.appendingPathComponent("same-image.jpeg")
        try jpeg.write(to: fileURL)

        let photoAttachment = try await root.attachmentService.stage(
            [
                PhotoAttachmentImport.candidate(
                    data: jpeg,
                    selectionIndex: 0,
                    declaredMediaType: "image/jpeg",
                    preferredFilenameExtension: "jpg"
                ),
            ],
            existing: []
        )[0]
        let fileAttachment = try await root.attachmentService.stageFiles(
            [fileURL],
            existing: []
        )[0]

        XCTAssertEqual(photoAttachment.kind, .image)
        XCTAssertEqual(fileAttachment.kind, .image)
        XCTAssertEqual(photoAttachment.kind, fileAttachment.kind)
        XCTAssertEqual(photoAttachment.mediaType, fileAttachment.mediaType)
    }

    private func stageText(using root: CompositionRoot) async throws -> MessageAttachment {
        try await root.attachmentService.stage(
            [
                AttachmentImportCandidate(
                    data: Data("safe text".utf8),
                    fileName: "notes.txt",
                    declaredMediaType: "text/plain"
                ),
            ],
            existing: []
        )[0]
    }

    private func attachmentFile(_ attachment: MessageAttachment, root: URL) -> URL {
        root.appendingPathComponent("Attachments")
            .appendingPathComponent(attachment.storageKey)
    }

    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("omnia-composition-attachments-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
