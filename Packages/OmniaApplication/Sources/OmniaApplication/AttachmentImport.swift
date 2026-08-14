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

/// Builds picker-independent photo candidates for the canonical attachment
/// pipeline. PhotosUI stays in Presentation; Application receives only bounded
/// bytes and normalized metadata, exactly like the generic file-import path.
public enum PhotoAttachmentImport {
    public static func candidate(
        data: Data,
        selectionIndex: Int,
        declaredMediaType: String?,
        preferredFilenameExtension: String?
    ) -> AttachmentImportCandidate {
        let baseName = "Photo-\(max(0, selectionIndex) + 1)"
        let fileExtension = normalizedExtension(preferredFilenameExtension)
        let fileName = fileExtension.map { baseName + "." + $0 } ?? baseName
        let mediaType = declaredMediaType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return AttachmentImportCandidate(
            data: data,
            fileName: fileName,
            declaredMediaType: mediaType?.isEmpty == false ? mediaType : nil
        )
    }

    public static func loadFailure(selectionIndex: Int) -> AttachmentError {
        .photoLoadFailed(fileName: "Photo-\(max(0, selectionIndex) + 1)")
    }

    private static func normalizedExtension(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty,
              normalized.count <= 10,
              normalized.allSatisfy({ $0.isLetter || $0.isNumber })
        else {
            return nil
        }
        return normalized
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
