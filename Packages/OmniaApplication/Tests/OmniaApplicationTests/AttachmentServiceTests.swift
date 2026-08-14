import Foundation
import OmniaDomain
import XCTest
@testable import OmniaApplication

private actor AttachmentMemoryStorage: AttachmentStorageProtocol {
    private var values: [String: Data] = [:]

    func store(
        _ data: Data,
        identity: AttachmentIdentity,
        fileExtension: String
    ) async throws -> String {
        let key = identity.canonicalString + "." + fileExtension
        values[key] = data
        return key
    }

    func data(for storageKey: String, maximumByteCount: Int) async throws -> Data {
        guard let data = values[storageKey], data.count <= maximumByteCount else {
            throw AttachmentError.storageUnavailable
        }
        return data
    }

    func remove(_ storageKey: String) async throws {
        values[storageKey] = nil
    }

    func allStorageKeys() async throws -> Set<String> {
        Set(values.keys)
    }

    func keys() -> Set<String> {
        Set(values.keys)
    }
}

private actor AttachmentSupportTable {
    private var values: [Capability: ModelCapabilitySupport]

    init(_ values: [Capability: ModelCapabilitySupport]) {
        self.values = values
    }

    func support(_ capability: Capability) -> ModelCapabilitySupport {
        values[capability] ?? .unknown
    }

    func set(_ value: ModelCapabilitySupport, for capability: Capability) {
        values[capability] = value
    }
}

private func attachmentService(
    storage: AttachmentMemoryStorage = AttachmentMemoryStorage(),
    limits: AttachmentLimits = AttachmentLimits(),
    support: AttachmentSupportTable = AttachmentSupportTable([
        .vision: .supported,
        .documentInput: .supported,
    ])
) -> AttachmentService {
    AttachmentService(
        storage: storage,
        limits: limits,
        loadFile: { _, _ in
            throw AttachmentError.unreadable(fileName: "Attachment")
        },
        prepare: { candidate in
            let value = candidate.fileName.lowercased()
            let kind: AttachmentKind
            let mediaType: String
            let fileExtension: String
            if value.hasSuffix(".png") {
                kind = .image
                mediaType = "image/png"
                fileExtension = "png"
            } else if value.hasSuffix(".pdf") {
                kind = .pdf
                mediaType = "application/pdf"
                fileExtension = "pdf"
            } else {
                kind = .plainText
                mediaType = "text/plain"
                fileExtension = "txt"
            }
            return PreparedAttachmentContent(
                data: candidate.data,
                fileName: candidate.fileName,
                mediaType: mediaType,
                kind: kind,
                fileExtension: fileExtension
            )
        },
        extractText: { attachment, data, limit in
            guard let text = String(data: data, encoding: .utf8) else {
                throw AttachmentError.extractionFailed(fileName: attachment.fileName)
            }
            guard text.count <= limit else {
                throw AttachmentError.extractedTextTooLarge(
                    fileName: attachment.fileName,
                    limit: limit
                )
            }
            return text
        },
        effectiveSupport: { capability, _ in
            await support.support(capability)
        }
    )
}

private let attachmentSelection = ProviderModelSelection(
    provider: ProviderIdentity(),
    model: ModelReference(name: "model")
)

final class AttachmentServiceTests: XCTestCase {
    func testStage_EnforcesCountPerFileAndAggregateLimitsAtomically() async throws {
        let storage = AttachmentMemoryStorage()
        let service = attachmentService(
            storage: storage,
            limits: AttachmentLimits(
                maximumCount: 2,
                maximumFileBytes: 4,
                maximumAggregateBytes: 6,
                maximumExtractedCharacters: 20
            )
        )

        do {
            _ = try await service.stage(
                [AttachmentImportCandidate(data: Data(repeating: 1, count: 5), fileName: "large.txt")],
                existing: []
            )
            XCTFail("expected per-file rejection")
        } catch {
            XCTAssertEqual(
                error as? AttachmentError,
                .fileTooLarge(fileName: "large.txt", limit: 4)
            )
        }

        do {
            _ = try await service.stage(
                [
                    AttachmentImportCandidate(data: Data("abc".utf8), fileName: "one.txt"),
                    AttachmentImportCandidate(data: Data("defg".utf8), fileName: "two.txt"),
                ],
                existing: []
            )
            XCTFail("expected aggregate rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .aggregateTooLarge(limit: 6))
        }
        let keysAfterAggregateFailure = await storage.keys()
        XCTAssertTrue(keysAfterAggregateFailure.isEmpty)

        do {
            _ = try await service.stage(
                [
                    AttachmentImportCandidate(data: Data("a".utf8), fileName: "one.txt"),
                    AttachmentImportCandidate(data: Data("b".utf8), fileName: "two.txt"),
                    AttachmentImportCandidate(data: Data("c".utf8), fileName: "three.txt"),
                ],
                existing: []
            )
            XCTFail("expected count rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .tooManyFiles(limit: 2))
        }
    }

    func testStage_PreventsDuplicatePickerResultsAndKeepsExistingItem() async throws {
        let storage = AttachmentMemoryStorage()
        let service = attachmentService(storage: storage)
        let existing = try await service.stage(
            [AttachmentImportCandidate(data: Data("same".utf8), fileName: "one.txt")],
            existing: []
        )

        do {
            _ = try await service.stage(
                [AttachmentImportCandidate(data: Data("same".utf8), fileName: "renamed.txt")],
                existing: existing
            )
            XCTFail("expected duplicate rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .duplicate(fileName: "renamed.txt"))
        }
        let keysAfterDuplicate = await storage.keys()
        XCTAssertEqual(keysAfterDuplicate.count, 1)
    }

    func testStage_EnforcesLimitsAfterContentNormalization() async throws {
        let storage = AttachmentMemoryStorage()
        let service = AttachmentService(
            storage: storage,
            limits: AttachmentLimits(
                maximumCount: 1,
                maximumFileBytes: 4,
                maximumAggregateBytes: 4,
                maximumExtractedCharacters: 20
            ),
            loadFile: { _, _ in
                throw AttachmentError.unreadable(fileName: "Attachment")
            },
            prepare: { candidate in
                PreparedAttachmentContent(
                    data: candidate.data + Data([0]),
                    fileName: candidate.fileName,
                    mediaType: "image/jpeg",
                    kind: .image,
                    fileExtension: "jpg"
                )
            },
            extractText: { _, _, _ in "" },
            effectiveSupport: { _, _ in .supported }
        )

        do {
            _ = try await service.stage(
                [AttachmentImportCandidate(data: Data(repeating: 1, count: 4), fileName: "photo.heic")],
                existing: []
            )
            XCTFail("expected normalized content rejection")
        } catch {
            XCTAssertEqual(
                error as? AttachmentError,
                .fileTooLarge(fileName: "photo.heic", limit: 4)
            )
        }
        let keys = await storage.keys()
        XCTAssertTrue(keys.isEmpty)
    }

    func testValidate_ReevaluatesImagePDFAndTextForExactModelSupport() async throws {
        let support = AttachmentSupportTable([
            .vision: .supported,
            .documentInput: .supported,
        ])
        let service = attachmentService(support: support)
        let attachments = try await service.stage(
            [
                AttachmentImportCandidate(data: Data([1]), fileName: "image.png"),
                AttachmentImportCandidate(data: Data("%PDF-".utf8), fileName: "document.pdf"),
                AttachmentImportCandidate(data: Data("text".utf8), fileName: "notes.txt"),
            ],
            existing: []
        )
        try await service.validate(attachments, for: attachmentSelection)

        await support.set(.unsupported, for: .vision)
        do {
            try await service.validate(attachments, for: attachmentSelection)
            XCTFail("expected image capability rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .capabilityUnsupported(.image))
        }

        await support.set(.unknown, for: .vision)
        do {
            try await service.validate(attachments, for: attachmentSelection)
            XCTFail("expected unverified image capability result")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .capabilityUnknown(.image))
        }

        await support.set(.supported, for: .vision)
        await support.set(.unknown, for: .documentInput)
        do {
            try await service.validate(attachments, for: attachmentSelection)
            XCTFail("expected conservative document rejection")
        } catch {
            XCTAssertEqual(error as? AttachmentError, .capabilityUnknown(.pdf))
        }
    }

    func testResolve_ProducesBoundedPayloadsAndCleanupRemovesOnlyOrphans() async throws {
        let storage = AttachmentMemoryStorage()
        let service = attachmentService(storage: storage)
        let attachments = try await service.stage(
            [
                AttachmentImportCandidate(data: Data([1, 2]), fileName: "image.png"),
                AttachmentImportCandidate(data: Data("notes".utf8), fileName: "notes.txt"),
            ],
            existing: []
        )
        let message = Message(role: .user, content: "Explain", attachments: attachments)

        let resolved = try await service.resolve(
            history: [message],
            for: attachmentSelection
        )

        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(
            resolved.map(\.attachment.identity),
            attachments.map(\.identity)
        )
        guard case .image(let imageData, let mediaType) = resolved[0].payload else {
            return XCTFail("expected image payload")
        }
        XCTAssertEqual(imageData, Data([1, 2]))
        XCTAssertEqual(mediaType, "image/png")
        XCTAssertEqual(resolved[1].payload, .extractedText("notes"))

        _ = try await service.stage(
            [AttachmentImportCandidate(data: Data("orphan".utf8), fileName: "orphan.txt")],
            existing: []
        )
        let removed = try await service.cleanupOrphans(referencedBy: [message])
        let remainingKeys = await storage.keys()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(remainingKeys, Set(attachments.map(\.storageKey)))
    }

    func testRemove_DeletesOnlyTheSelectedStagedItemAndIsIdempotent() async throws {
        let storage = AttachmentMemoryStorage()
        let service = attachmentService(storage: storage)
        let attachments = try await service.stage(
            [
                AttachmentImportCandidate(data: Data("first".utf8), fileName: "first.txt"),
                AttachmentImportCandidate(data: Data("second".utf8), fileName: "second.txt"),
            ],
            existing: []
        )

        try await service.remove(attachments[0])
        try await service.remove(attachments[0])

        let remainingKeys = await storage.keys()
        XCTAssertEqual(remainingKeys, [attachments[1].storageKey])
    }

    func testCandidateDescriptionsRedactBytesAndPrivateDirectories() {
        let candidate = AttachmentImportCandidate(
            data: Data("secret document text".utf8),
            fileName: "/private/mobile/notes.txt",
            declaredMediaType: "text/plain"
        )

        XCTAssertFalse(candidate.description.contains("secret document text"))
        XCTAssertFalse(candidate.description.contains("/private/mobile"))
        XCTAssertTrue(candidate.description.contains("notes.txt"))
        XCTAssertTrue(candidate.description.contains("<redacted>"))
    }
}
