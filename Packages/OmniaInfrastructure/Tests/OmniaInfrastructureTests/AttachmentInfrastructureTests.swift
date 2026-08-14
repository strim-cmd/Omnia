import Foundation
import OmniaDomain
import XCTest
@testable import OmniaInfrastructure

final class AttachmentInfrastructureTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("omnia-attachment-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    func testContentProcessorDetectsSupportedMagicAndSafeTextMIME() throws {
        let processor = AttachmentContentProcessor()
        let jpeg = try processor.prepare(
            data: Data([0xFF, 0xD8, 0xFF, 0x00]),
            fileName: "/private/input/photo.bin"
        )
        let png = try processor.prepare(
            data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
            fileName: "photo"
        )
        let gif = try processor.prepare(
            data: Data("GIF89a".utf8),
            fileName: "animated.data"
        )
        var webpData = Data("RIFF0000WEBP".utf8)
        webpData.append(0)
        let webp = try processor.prepare(data: webpData, fileName: "image")
        let pdf = try processor.prepare(
            data: Data("%PDF-1.7".utf8),
            fileName: "report.bin"
        )
        let text = try processor.prepare(
            data: Data(#"{"safe":true}"#.utf8),
            fileName: "data.json",
            declaredMediaType: "application/octet-stream"
        )

        XCTAssertEqual(jpeg.kind, .image)
        XCTAssertEqual(jpeg.mediaType, "image/jpeg")
        XCTAssertEqual(jpeg.fileName, "photo.jpg")
        XCTAssertEqual(png.mediaType, "image/png")
        XCTAssertEqual(gif.mediaType, "image/gif")
        XCTAssertEqual(webp.mediaType, "image/webp")
        XCTAssertEqual(pdf.kind, .pdf)
        XCTAssertEqual(pdf.mediaType, "application/pdf")
        XCTAssertEqual(text.kind, .plainText)
        XCTAssertEqual(text.mediaType, "application/json")
    }

    func testFileImporterClassifiesJPGAndPNGAsImagesWhilePDFRemainsDocument() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures: [(String, Data, AttachmentKind, String)] = [
            ("camera.jpg", Data([0xFF, 0xD8, 0xFF, 0x00]), .image, "image/jpeg"),
            (
                "screenshot.png",
                Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
                .image,
                "image/png"
            ),
            ("manual.pdf", Data("%PDF-1.7".utf8), .pdf, "application/pdf"),
        ]
        let processor = AttachmentContentProcessor()

        for (name, data, expectedKind, expectedMediaType) in fixtures {
            let url = root.appendingPathComponent(name)
            try data.write(to: url)
            let loaded = try processor.loadFile(url, maximumByteCount: 1024)
            let prepared = try processor.prepare(
                data: loaded.data,
                fileName: loaded.fileName,
                declaredMediaType: loaded.declaredMediaType
            )

            XCTAssertEqual(prepared.kind, expectedKind, name)
            XCTAssertEqual(prepared.mediaType, expectedMediaType, name)
        }
    }

    func testContentProcessorRejectsUnsafeEmptyBinaryAndUnsupportedInput() throws {
        let processor = AttachmentContentProcessor()
        for candidate in [
            (Data(), "empty.txt"),
            (Data([0, 1, 2]), "binary.txt"),
            (Data("plain".utf8), "archive.zip"),
        ] {
            XCTAssertThrowsError(
                try processor.prepare(data: candidate.0, fileName: candidate.1)
            ) { error in
                XCTAssertTrue(error is AttachmentError)
            }
        }
    }

    func testTextExtractionEnforcesCharacterLimitAndPDFFailureIsExplicit() throws {
        let processor = AttachmentContentProcessor()
        let textAttachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "notes.txt",
            mediaType: "text/plain",
            kind: .plainText,
            byteCount: 5,
            storageKey: "notes.txt"
        )
        XCTAssertEqual(
            try processor.extractText(
                from: textAttachment,
                data: Data("hello".utf8),
                maximumCharacters: 5
            ),
            "hello"
        )
        XCTAssertThrowsError(
            try processor.extractText(
                from: textAttachment,
                data: Data("hello".utf8),
                maximumCharacters: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? AttachmentError,
                .extractedTextTooLarge(fileName: "notes.txt", limit: 4)
            )
        }

        let pdfAttachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "scan.pdf",
            mediaType: "application/pdf",
            kind: .pdf,
            byteCount: 8,
            storageKey: "scan.pdf"
        )
        XCTAssertThrowsError(
            try processor.extractText(
                from: pdfAttachment,
                data: Data("%PDF-bad".utf8),
                maximumCharacters: 100
            )
        ) { error in
            XCTAssertEqual(
                error as? AttachmentError,
                .extractionFailed(fileName: "scan.pdf")
            )
        }
    }

    func testFileLoadAndStorageCopyAreBoundedDurableAndOpaque() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let external = root.appendingPathComponent("temporary-source.txt")
        try Data("durable".utf8).write(to: external)
        let processor = AttachmentContentProcessor()
        let loaded = try processor.loadFile(external, maximumByteCount: 7)
        let prepared = try processor.prepare(
            data: loaded.data,
            fileName: loaded.fileName,
            declaredMediaType: loaded.declaredMediaType
        )
        let store = FileAttachmentStorage(
            directory: root.appendingPathComponent("owned")
        )
        let key = try await store.store(
            prepared.data,
            identity: AttachmentIdentity(),
            fileExtension: prepared.fileExtension
        )
        try FileManager.default.removeItem(at: external)

        XCTAssertFalse(key.contains(root.path))
        XCTAssertFalse(key.contains("/"))
        let durableData = try await store.data(for: key, maximumByteCount: 7)
        XCTAssertEqual(durableData, Data("durable".utf8))
        let keys = try await store.allStorageKeys()
        XCTAssertEqual(keys, Set([key]))
        do {
            _ = try await store.data(for: key, maximumByteCount: 6)
            XCTFail("expected bounded read rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .storageUnavailable)
        }
        do {
            _ = try await store.data(for: "../" + key, maximumByteCount: 7)
            XCTFail("expected traversal rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .storageUnavailable)
        }
        try await store.remove(key)
        try await store.remove(key)
        let keysAfterRemoval = try await store.allStorageKeys()
        XCTAssertTrue(keysAfterRemoval.isEmpty)
    }

    func testConversationSerializerPersistsMetadataOnlyAndReloadsExactly() throws {
        let attachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "notes.txt",
            mediaType: "text/plain",
            kind: .plainText,
            byteCount: 12,
            storageKey: "opaque-key.txt"
        )
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(
            Message(role: .user, content: "Read this", attachments: [attachment])
        )
        let serializer = ConversationSerializer()
        let encoded = try serializer.encode(conversation)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(try serializer.decode(from: encoded), conversation)
        XCTAssertTrue(json.contains("opaque-key.txt"))
        XCTAssertFalse(json.contains("data:"))
        XCTAssertFalse(json.contains("Read this\n[Attachment"))
        XCTAssertFalse(json.contains("/private/"))
    }

    func testMultimodalMappingPreservesTextThenMultipleImagesInPickerOrder() throws {
        let first = messageAttachment(name: "one.png", key: "one.png")
        let second = messageAttachment(name: "two.jpg", key: "two.jpg", mediaType: "image/jpeg")
        let message = Message(
            role: .user,
            content: "Compare",
            attachments: [first, second]
        )
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [message],
            model: ModelReference(name: "model"),
            resolvedAttachments: [
                ResolvedAttachment(
                    attachment: first,
                    payload: .image(data: Data([1]), mediaType: "image/png")
                ),
                ResolvedAttachment(
                    attachment: second,
                    payload: .image(data: Data([2]), mediaType: "image/jpeg")
                ),
            ]
        )

        let wire = try CapabilityMapping.request(from: request)
        guard case .parts(let parts) = wire.messages[0].content else {
            return XCTFail("expected typed content parts")
        }
        XCTAssertEqual(parts, [
            .text("Compare"),
            .imageURL("data:image/png;base64,AQ=="),
            .imageURL("data:image/jpeg;base64,Ag=="),
        ])
    }

    func testDocumentMappingUsesExplicitExtractedTextAndNeverDropsMissingPayload() throws {
        let attachment = MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: "notes.txt",
            mediaType: "text/plain",
            kind: .plainText,
            byteCount: 5,
            storageKey: "notes.txt"
        )
        let message = Message(role: .user, content: "", attachments: [attachment])
        let mapped = try CapabilityMapping.request(
            from: ConversationRequest(
                identity: CapabilityRequestIdentity(),
                history: [message],
                model: ModelReference(name: "model"),
                resolvedAttachments: [
                    ResolvedAttachment(
                        attachment: attachment,
                        payload: .extractedText("hello")
                    ),
                ]
            )
        )
        XCTAssertEqual(
            mapped.messages[0].content,
            .parts([.text("[Attachment: notes.txt (text/plain)]\nhello")])
        )

        XCTAssertThrowsError(
            try CapabilityMapping.request(
                from: StreamingRequest(
                    identity: CapabilityRequestIdentity(),
                    history: [message],
                    model: ModelReference(name: "model")
                )
            )
        ) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidRequest)
        }
    }

    private func messageAttachment(
        name: String,
        key: String,
        mediaType: String = "image/png"
    ) -> MessageAttachment {
        MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: name,
            mediaType: mediaType,
            kind: .image,
            byteCount: 1,
            storageKey: key
        )
    }
}
