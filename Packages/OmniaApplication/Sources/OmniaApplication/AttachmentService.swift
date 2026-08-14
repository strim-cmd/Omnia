import Foundation
import OmniaDomain

/// Stages picker input into app-owned storage, validates model capabilities,
/// resolves bounded request payloads, and owns attachment cleanup.
public actor AttachmentService {
    let storage: any AttachmentStorageProtocol
    let limits: AttachmentLimits
    let loadFile: @Sendable (URL, Int) async throws -> AttachmentImportCandidate
    let prepare: @Sendable (AttachmentImportCandidate) throws -> PreparedAttachmentContent
    let extractText: @Sendable (MessageAttachment, Data, Int) throws -> String
    let effectiveSupport: @Sendable (
        Capability,
        ProviderModelSelection
    ) async throws -> ModelCapabilitySupport

    public init(
        storage: any AttachmentStorageProtocol,
        limits: AttachmentLimits = AttachmentLimits(),
        loadFile: @escaping @Sendable (URL, Int) async throws -> AttachmentImportCandidate,
        prepare: @escaping @Sendable (AttachmentImportCandidate) throws -> PreparedAttachmentContent,
        extractText: @escaping @Sendable (MessageAttachment, Data, Int) throws -> String,
        effectiveSupport: @escaping @Sendable (
            Capability,
            ProviderModelSelection
        ) async throws -> ModelCapabilitySupport
    ) {
        self.storage = storage
        self.limits = limits
        self.loadFile = loadFile
        self.prepare = prepare
        self.extractText = extractText
        self.effectiveSupport = effectiveSupport
    }

    public func stageFiles(
        _ urls: [URL],
        existing: [MessageAttachment]
    ) async throws -> [MessageAttachment] {
        var candidates: [AttachmentImportCandidate] = []
        candidates.reserveCapacity(urls.count)
        for url in urls {
            do {
                candidates.append(try await loadFile(url, limits.maximumFileBytes))
            } catch let error as AttachmentError {
                throw error
            } catch {
                throw AttachmentError.unreadable(fileName: Self.safeName(url.lastPathComponent))
            }
        }
        return try await stage(candidates, existing: existing)
    }

    /// Atomically stages a picker batch. If one item fails, every file created
    /// by this batch is removed and the caller's existing staged set is intact.
    public func stage(
        _ candidates: [AttachmentImportCandidate],
        existing: [MessageAttachment]
    ) async throws -> [MessageAttachment] {
        guard existing.count + candidates.count <= limits.maximumCount else {
            throw AttachmentError.tooManyFiles(limit: limits.maximumCount)
        }
        var aggregate = 0
        for attachment in existing {
            guard attachment.byteCount >= 0 else {
                throw AttachmentError.storageUnavailable
            }
            let (next, overflow) = aggregate.addingReportingOverflow(
                attachment.byteCount
            )
            guard !overflow, next <= limits.maximumAggregateBytes else {
                throw AttachmentError.aggregateTooLarge(
                    limit: limits.maximumAggregateBytes
                )
            }
            aggregate = next
        }
        var result = existing
        var newlyStored: [MessageAttachment] = []
        do {
            for candidate in candidates {
                let safeName = Self.safeName(candidate.fileName)
                guard !candidate.data.isEmpty else {
                    throw AttachmentError.empty(fileName: safeName)
                }
                guard candidate.data.count <= limits.maximumFileBytes else {
                    throw AttachmentError.fileTooLarge(
                        fileName: safeName,
                        limit: limits.maximumFileBytes
                    )
                }
                let prepared = try prepare(
                    AttachmentImportCandidate(
                        data: candidate.data,
                        fileName: safeName,
                        declaredMediaType: candidate.declaredMediaType
                    )
                )
                guard !prepared.data.isEmpty else {
                    throw AttachmentError.empty(fileName: Self.safeName(prepared.fileName))
                }
                guard prepared.data.count <= limits.maximumFileBytes else {
                    throw AttachmentError.fileTooLarge(
                        fileName: Self.safeName(prepared.fileName),
                        limit: limits.maximumFileBytes
                    )
                }
                let (nextAggregate, overflow) = aggregate.addingReportingOverflow(
                    prepared.data.count
                )
                guard !overflow,
                      nextAggregate <= limits.maximumAggregateBytes
                else {
                    throw AttachmentError.aggregateTooLarge(
                        limit: limits.maximumAggregateBytes
                    )
                }
                aggregate = nextAggregate
                if try await containsDuplicate(prepared.data, in: result) {
                    throw AttachmentError.duplicate(fileName: prepared.fileName)
                }
                let identity = AttachmentIdentity()
                let key = try await storage.store(
                    prepared.data,
                    identity: identity,
                    fileExtension: prepared.fileExtension
                )
                let attachment = MessageAttachment(
                    identity: identity,
                    fileName: prepared.fileName,
                    mediaType: prepared.mediaType,
                    kind: prepared.kind,
                    byteCount: prepared.data.count,
                    storageKey: key
                )
                result.append(attachment)
                newlyStored.append(attachment)
            }
            return result
        } catch {
            for attachment in newlyStored {
                try? await storage.remove(attachment.storageKey)
            }
            if let attachmentError = error as? AttachmentError {
                throw attachmentError
            }
            throw AttachmentError.storageUnavailable
        }
    }

    private func containsDuplicate(
        _ data: Data,
        in attachments: [MessageAttachment]
    ) async throws -> Bool {
        for attachment in attachments where attachment.byteCount == data.count {
            let stored = try await storage.data(
                for: attachment.storageKey,
                maximumByteCount: limits.maximumFileBytes
            )
            if stored == data { return true }
        }
        return false
    }

    static func capability(for kind: AttachmentKind) -> Capability {
        switch kind {
        case .image: .vision
        case .pdf, .plainText: .documentInput
        }
    }

    static func safeName(_ value: String) -> String {
        let leaf = value.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init) ?? "Attachment"
        let trimmed = leaf.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Attachment" : String(trimmed.prefix(160))
    }
}
