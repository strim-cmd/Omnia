import Foundation
import OmniaFoundation

/// The identity kind of a user-owned attachment.
public struct AttachmentIdentityKind: IdentifierKind {}

/// A stable identity shared by staged, persisted, and request attachment state.
public typealias AttachmentIdentity = Identifier<AttachmentIdentityKind>

/// The bounded attachment kinds supported by the v1 composer pipeline.
public enum AttachmentKind: String, Codable, Equatable, Hashable, Sendable {
    case image
    case pdf
    case plainText
}

/// Durable, safe metadata for one app-owned attachment.
///
/// The storage key is opaque and never an external sandbox path. File bytes
/// and extracted document text are absent so conversation JSON stays bounded.
public struct MessageAttachment: Codable, Equatable, Hashable, Sendable {
    public let identity: AttachmentIdentity
    public let fileName: String
    public let mediaType: String
    public let kind: AttachmentKind
    public let byteCount: Int
    public let storageKey: String

    public init(
        identity: AttachmentIdentity,
        fileName: String,
        mediaType: String,
        kind: AttachmentKind,
        byteCount: Int,
        storageKey: String
    ) {
        self.identity = identity
        self.fileName = fileName
        self.mediaType = mediaType
        self.kind = kind
        self.byteCount = byteCount
        self.storageKey = storageKey
    }
}

/// A validated, normalized payload ready for app-owned storage.
public struct PreparedAttachmentContent: Equatable, Sendable {
    public let data: Data
    public let fileName: String
    public let mediaType: String
    public let kind: AttachmentKind
    public let fileExtension: String

    public init(
        data: Data,
        fileName: String,
        mediaType: String,
        kind: AttachmentKind,
        fileExtension: String
    ) {
        self.data = data
        self.fileName = fileName
        self.mediaType = mediaType
        self.kind = kind
        self.fileExtension = fileExtension
    }
}

/// Transient request content resolved from a durable attachment reference.
public enum AttachmentPayload: Equatable, Sendable {
    case image(data: Data, mediaType: String)
    case extractedText(String)
}

/// A durable attachment paired with its transient request payload.
public struct ResolvedAttachment: Equatable, Sendable {
    public let attachment: MessageAttachment
    public let payload: AttachmentPayload

    public init(attachment: MessageAttachment, payload: AttachmentPayload) {
        self.attachment = attachment
        self.payload = payload
    }
}

/// Safe, actionable attachment failures. Cases carry only leaf filenames,
/// counts, and limits, never private paths or attachment contents.
public enum AttachmentError: Error, Equatable, Sendable {
    case unsupportedType(fileName: String)
    case unreadable(fileName: String)
    case empty(fileName: String)
    case fileTooLarge(fileName: String, limit: Int)
    case aggregateTooLarge(limit: Int)
    case tooManyFiles(limit: Int)
    case duplicate(fileName: String)
    case capabilityUnsupported(AttachmentKind)
    case capabilityUnknown(AttachmentKind)
    case extractionFailed(fileName: String)
    case extractedTextTooLarge(fileName: String, limit: Int)
    case storageUnavailable
}

/// The storage contract for attachment bytes. Implementations own file access;
/// consumers see only opaque keys and bounded data.
public protocol AttachmentStorageProtocol: Sendable {
    func store(
        _ data: Data,
        identity: AttachmentIdentity,
        fileExtension: String
    ) async throws -> String

    func data(for storageKey: String, maximumByteCount: Int) async throws -> Data
    func remove(_ storageKey: String) async throws
    func allStorageKeys() async throws -> Set<String>
}
