import Foundation
import OmniaDomain

/// App-owned attachment byte storage addressed only by opaque keys.
public struct FileAttachmentStorage: AttachmentStorageProtocol, Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory.standardizedFileURL
    }

    public func store(
        _ data: Data,
        identity: AttachmentIdentity,
        fileExtension: String
    ) async throws -> String {
        let normalizedExtension = fileExtension.lowercased()
        guard !normalizedExtension.isEmpty,
              normalizedExtension.count <= 12,
              normalizedExtension.allSatisfy({
                  $0.isASCII && ($0.isLetter || $0.isNumber)
              })
        else {
            throw AttachmentError.storageUnavailable
        }
        let key = identity.canonicalString + "." + normalizedExtension
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: try fileURL(for: key), options: .atomic)
            return key
        } catch let error as AttachmentError {
            throw error
        } catch {
            throw AttachmentError.storageUnavailable
        }
    }

    public func data(
        for storageKey: String,
        maximumByteCount: Int
    ) async throws -> Data {
        guard maximumByteCount >= 0, maximumByteCount < Int.max else {
            throw AttachmentError.storageUnavailable
        }
        do {
            let handle = try FileHandle(forReadingFrom: try fileURL(for: storageKey))
            defer { try? handle.close() }
            let value = try handle.read(upToCount: maximumByteCount + 1) ?? Data()
            guard value.count <= maximumByteCount else {
                throw AttachmentError.storageUnavailable
            }
            return value
        } catch let error as AttachmentError {
            throw error
        } catch {
            throw AttachmentError.storageUnavailable
        }
    }

    public func remove(_ storageKey: String) async throws {
        let url = try fileURL(for: storageKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw AttachmentError.storageUnavailable
        }
    }

    public func allStorageKeys() async throws -> Set<String> {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: directory.path,
            isDirectory: &isDirectory
        ) else {
            return []
        }
        guard isDirectory.boolValue else {
            throw AttachmentError.storageUnavailable
        }
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            return Set(
                try urls.compactMap { url in
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                    return values.isRegularFile == true ? url.lastPathComponent : nil
                }
            )
        } catch {
            throw AttachmentError.storageUnavailable
        }
    }

    private func fileURL(for key: String) throws -> URL {
        guard !key.isEmpty,
              key == URL(fileURLWithPath: key).lastPathComponent,
              !key.contains("/"),
              !key.contains("\\")
        else {
            throw AttachmentError.storageUnavailable
        }
        let candidate = directory.appendingPathComponent(key, isDirectory: false)
            .standardizedFileURL
        guard candidate.deletingLastPathComponent().standardizedFileURL.path
                == directory.standardizedFileURL.path
        else {
            throw AttachmentError.storageUnavailable
        }
        return candidate
    }
}
