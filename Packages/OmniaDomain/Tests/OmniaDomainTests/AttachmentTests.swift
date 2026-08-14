import Foundation
import XCTest
@testable import OmniaDomain

final class AttachmentTests: XCTestCase {
    func testMessagePreservesAttachmentOrderAndDefaultsToNone() {
        let first = attachment(name: "one.png", kind: .image)
        let second = attachment(name: "two.txt", kind: .plainText)

        XCTAssertTrue(Message(role: .user, content: "text").attachments.isEmpty)
        XCTAssertEqual(
            Message(
                role: .user,
                content: "text",
                attachments: [first, second]
            ).attachments,
            [first, second]
        )
    }

    func testAttachmentMetadataCodableRoundTripsWithoutPayload() throws {
        let value = attachment(name: "report.pdf", kind: .pdf)
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(try JSONDecoder().decode(MessageAttachment.self, from: data), value)
        XCTAssertFalse(json.contains("base64"))
        XCTAssertFalse(json.contains("document text"))
    }

    func testResolvedPayloadsRemainTransientRequestValues() {
        let value = attachment(name: "photo.png", kind: .image)
        let resolved = ResolvedAttachment(
            attachment: value,
            payload: .image(data: Data([1, 2]), mediaType: "image/png")
        )
        let request = StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .user, content: "", attachments: [value]),
            ],
            model: ModelReference(name: "model"),
            resolvedAttachments: [resolved]
        )

        XCTAssertEqual(request.resolvedAttachments, [resolved])
        XCTAssertEqual(request.history[0].attachments, [value])
    }

    private func attachment(
        name: String,
        kind: AttachmentKind
    ) -> MessageAttachment {
        MessageAttachment(
            identity: AttachmentIdentity(),
            fileName: name,
            mediaType: kind == .image ? "image/png" : "text/plain",
            kind: kind,
            byteCount: 2,
            storageKey: UUID().uuidString + ".data"
        )
    }
}
