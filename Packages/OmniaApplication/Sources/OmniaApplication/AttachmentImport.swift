import Foundation
import OmniaDomain

/// Raw picker output delivered to the Application boundary. Its description is
/// metadata-only so file bytes cannot enter diagnostics.
public struct AttachmentImportCandidate: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let data: Data
    public let fileName: String
    public let declaredMediaType: String?

    public init(data: Data, fileName: String, declaredMediaType: String? = nil) {
        self.data = data
        self.fileName = fileName
        self.declaredMediaType = declaredMediaType
    }

    public var description: String {
        "AttachmentImportCandidate(fileName: \(Self.safeName(fileName)), byteCount: \(data.count), declaredMediaType: \(declaredMediaType ?? "unknown"), data: <redacted>)"
    }

    public var debugDescription: String { description }

    private static func safeName(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init)
            ?? "Attachment"
    }
}

/// Explicit, deterministic limits for the v1 attachment pipeline.
public struct AttachmentLimits: Equatable, Sendable {
    public let maximumCount: Int
    public let maximumFileBytes: Int
    public let maximumAggregateBytes: Int
    public let maximumExtractedCharacters: Int

    public init(
        maximumCount: Int = 8,
        maximumFileBytes: Int = 10 * 1024 * 1024,
        maximumAggregateBytes: Int = 25 * 1024 * 1024,
        maximumExtractedCharacters: Int = 200_000
    ) {
        self.maximumCount = maximumCount
        self.maximumFileBytes = maximumFileBytes
        self.maximumAggregateBytes = maximumAggregateBytes
        self.maximumExtractedCharacters = maximumExtractedCharacters
    }
}
