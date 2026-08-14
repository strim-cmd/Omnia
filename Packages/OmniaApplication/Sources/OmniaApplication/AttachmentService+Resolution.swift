import Foundation
import OmniaDomain

public extension AttachmentService {
    /// Validates a staged set against deterministic limits and the exact
    /// provider/model route that will receive it.
    func validate(
        _ attachments: [MessageAttachment],
        for selection: ProviderModelSelection
    ) async throws {
        guard attachments.count <= limits.maximumCount else {
            throw AttachmentError.tooManyFiles(limit: limits.maximumCount)
        }
        var aggregate = 0
        for attachment in attachments {
            guard attachment.byteCount > 0 else {
                throw AttachmentError.empty(fileName: Self.safeName(attachment.fileName))
            }
            guard attachment.byteCount <= limits.maximumFileBytes else {
                throw AttachmentError.fileTooLarge(
                    fileName: Self.safeName(attachment.fileName),
                    limit: limits.maximumFileBytes
                )
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
        var checkedCapabilities = Set<Capability>()
        for attachment in attachments {
            let kind = attachment.kind
            let capability = Self.capability(for: kind)
            guard checkedCapabilities.insert(capability).inserted else { continue }
            switch try await effectiveSupport(capability, selection) {
            case .supported:
                continue
            case .unsupported:
                throw AttachmentError.capabilityUnsupported(kind)
            case .unknown:
                throw AttachmentError.capabilityUnknown(kind)
            }
        }
    }

    /// Resolves durable references into transient, bounded provider payloads.
    /// No payload or private path is persisted or exposed in diagnostics.
    func resolve(
        history: [Message],
        for selection: ProviderModelSelection
    ) async throws -> [ResolvedAttachment] {
        let attachments = history.flatMap(\.attachments)
        guard !attachments.isEmpty else { return [] }

        var checkedCapabilities = Set<Capability>()
        for attachment in attachments {
            let kind = attachment.kind
            let capability = Self.capability(for: kind)
            guard checkedCapabilities.insert(capability).inserted else { continue }
            switch try await effectiveSupport(capability, selection) {
            case .supported:
                continue
            case .unsupported:
                throw AttachmentError.capabilityUnsupported(kind)
            case .unknown:
                throw AttachmentError.capabilityUnknown(kind)
            }
        }

        var aggregate = 0
        var resolvedByIdentity: [AttachmentIdentity: ResolvedAttachment] = [:]
        for attachment in attachments where resolvedByIdentity[attachment.identity] == nil {
            guard attachment.byteCount > 0 else {
                throw AttachmentError.empty(fileName: Self.safeName(attachment.fileName))
            }
            guard attachment.byteCount <= limits.maximumFileBytes else {
                throw AttachmentError.fileTooLarge(
                    fileName: Self.safeName(attachment.fileName),
                    limit: limits.maximumFileBytes
                )
            }
            let (nextAggregate, overflow) = aggregate.addingReportingOverflow(
                attachment.byteCount
            )
            guard !overflow,
                  nextAggregate <= limits.maximumAggregateBytes
            else {
                throw AttachmentError.aggregateTooLarge(limit: limits.maximumAggregateBytes)
            }
            aggregate = nextAggregate

            let data: Data
            do {
                data = try await storage.data(
                    for: attachment.storageKey,
                    maximumByteCount: limits.maximumFileBytes
                )
            } catch let error as AttachmentError {
                throw error
            } catch {
                throw AttachmentError.storageUnavailable
            }
            guard data.count == attachment.byteCount else {
                throw AttachmentError.storageUnavailable
            }

            let payload: AttachmentPayload
            switch attachment.kind {
            case .image:
                payload = .image(data: data, mediaType: attachment.mediaType)
            case .pdf, .plainText:
                let text: String
                do {
                    text = try extractText(
                        attachment,
                        data,
                        limits.maximumExtractedCharacters
                    )
                } catch let error as AttachmentError {
                    throw error
                } catch {
                    throw AttachmentError.extractionFailed(
                        fileName: Self.safeName(attachment.fileName)
                    )
                }
                guard text.count <= limits.maximumExtractedCharacters else {
                    throw AttachmentError.extractedTextTooLarge(
                        fileName: Self.safeName(attachment.fileName),
                        limit: limits.maximumExtractedCharacters
                    )
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AttachmentError.extractionFailed(
                        fileName: Self.safeName(attachment.fileName)
                    )
                }
                payload = .extractedText(text)
            }
            resolvedByIdentity[attachment.identity] = ResolvedAttachment(
                attachment: attachment,
                payload: payload
            )
        }

        return attachments.compactMap { resolvedByIdentity[$0.identity] }
    }

    func remove(_ attachment: MessageAttachment) async throws {
        do {
            try await storage.remove(attachment.storageKey)
        } catch let error as AttachmentError {
            throw error
        } catch {
            throw AttachmentError.storageUnavailable
        }
    }

    func remove(_ attachments: [MessageAttachment]) async throws {
        for attachment in attachments {
            try await remove(attachment)
        }
    }

    /// Removes app-owned files not referenced by any persisted message.
    @discardableResult
    func cleanupOrphans(referencedBy messages: [Message]) async throws -> Int {
        let referenced = Set(messages.flatMap(\.attachments).map(\.storageKey))
        let stored: Set<String>
        do {
            stored = try await storage.allStorageKeys()
        } catch {
            throw AttachmentError.storageUnavailable
        }
        let orphaned = stored.subtracting(referenced)
        for key in orphaned {
            do {
                try await storage.remove(key)
            } catch {
                throw AttachmentError.storageUnavailable
            }
        }
        return orphaned.count
    }
}
