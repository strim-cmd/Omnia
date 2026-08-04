import Foundation
import OmniaDomain

/// The file-based JSON document store (DES-010 §3.2, ARC-005).
///
/// The storage engine foundation: it persists `Codable` documents as JSON files
/// on disk, addressed by identity key — save, load, delete, and list. Storage is
/// a replaceable technology hidden behind the Domain repository protocols
/// (DES-009 §3.5, ARC-005); the engine is internal to the package and is
/// composed into the repository implementations, never exposed as a public
/// dependency (DES-010 §3.2, ARC-009).
///
/// The engine owns no business rules (ARC-005): it stores and restores
/// documents exactly as given. Stored data is user-owned, exportable, and
/// removable by the user (ARC-005). The engine never carries credential
/// meaning; credential isolation is enforced by the serializers and
/// repositories that compose it.
///
/// Every failure — file access, encoding, decoding, or an unreachable
/// directory — is translated to the Domain `RepositoryError.storageUnavailable`;
/// no raw storage error crosses the boundary (DES-009 §3.9).
///
/// Serialized-form stability: each document is stored as a single UTF-8 JSON
/// file whose keys are ordered, so the persisted form is deterministic and
/// round-trips exactly across versions (DES-004 §4, ARC-005).
internal struct JSONDocumentStore: Sendable {
    /// The directory that holds the store's JSON files.
    let directoryURL: URL

    /// Creates a store rooted at `directoryURL`.
    ///
    /// The directory is created lazily on the first write; a store rooted at a
    /// directory that is actually a regular file fails every operation with
    /// `RepositoryError.storageUnavailable`.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// Saves `document` under `key`, replacing any previously stored document
    /// with the same key.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the directory cannot
    ///   be reached or the document cannot be encoded or written.
    func save<Document: Codable & Sendable>(_ document: Document, key: String) throws {
        do {
            try createDirectoryIfNeeded()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    /// Returns the document stored under `key`, or `nil` when none is stored.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored document
    ///   cannot be read or decoded.
    func load<Document: Codable & Sendable>(key: String) throws -> Document? {
        let url = fileURL(for: key)
        guard fileExists(at: url) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    /// Removes the document stored under `key`.
    ///
    /// Removing a key that is not stored is not an error; the operation is
    /// idempotent (DES-009 §3.5).
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the document cannot
    ///   be removed.
    func delete(key: String) throws {
        let url = fileURL(for: key)
        guard fileExists(at: url) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    /// Returns the keys of all stored documents, in a stable order.
    ///
    /// A store with no directory yet holds no documents and returns an empty
    /// list.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the directory cannot
    ///   be read.
    func allKeys() throws -> [String] {
        guard directoryExists() else { return [] }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
            return contents
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            throw RepositoryError.storageUnavailable
        }
    }

    private func createDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(key).appendingPathExtension("json")
    }

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func directoryExists() -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: directoryURL.path,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }
}
