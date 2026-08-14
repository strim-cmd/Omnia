import Foundation
import OmniaDomain
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct LoadedAttachmentFile: Sendable {
    public let data: Data
    public let fileName: String
    public let declaredMediaType: String?

    public init(data: Data, fileName: String, declaredMediaType: String?) {
        self.data = data
        self.fileName = fileName
        self.declaredMediaType = declaredMediaType
    }
}

/// Conservative attachment loading, type validation, normalization, and
/// bounded text extraction. It never trusts a picker MIME declaration alone.
public struct AttachmentContentProcessor: Sendable {
    private let maximumPDFPages: Int

    public init(maximumPDFPages: Int = 200) {
        self.maximumPDFPages = maximumPDFPages
    }

    public func loadFile(
        _ url: URL,
        maximumByteCount: Int
    ) throws -> LoadedAttachmentFile {
        let fileName = Self.safeName(url.lastPathComponent)
        guard maximumByteCount >= 0, maximumByteCount < Int.max else {
            throw AttachmentError.fileTooLarge(
                fileName: fileName,
                limit: max(0, maximumByteCount)
            )
        }
        #if os(iOS) || os(macOS)
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        #endif
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumByteCount + 1) ?? Data()
            guard data.count <= maximumByteCount else {
                throw AttachmentError.fileTooLarge(
                    fileName: fileName,
                    limit: maximumByteCount
                )
            }
            return LoadedAttachmentFile(
                data: data,
                fileName: fileName,
                declaredMediaType: Self.mediaType(for: url)
            )
        } catch let error as AttachmentError {
            throw error
        } catch {
            throw AttachmentError.unreadable(fileName: fileName)
        }
    }

    public func prepare(
        data: Data,
        fileName: String,
        declaredMediaType: String? = nil
    ) throws -> PreparedAttachmentContent {
        let safeName = Self.safeName(fileName)
        guard !data.isEmpty else {
            throw AttachmentError.empty(fileName: safeName)
        }
        if Self.isJPEG(data) {
            return image(data, name: safeName, mediaType: "image/jpeg", extension: "jpg")
        }
        if Self.isPNG(data) {
            return image(data, name: safeName, mediaType: "image/png", extension: "png")
        }
        if Self.isGIF(data) {
            return image(data, name: safeName, mediaType: "image/gif", extension: "gif")
        }
        if Self.isWebP(data) {
            return image(data, name: safeName, mediaType: "image/webp", extension: "webp")
        }
        if Self.isHEIF(data) {
            #if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw AttachmentError.unreadable(fileName: safeName)
            }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw AttachmentError.unreadable(fileName: safeName)
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw AttachmentError.unreadable(fileName: safeName)
            }
            return image(
                output as Data,
                name: Self.replacingExtension(of: safeName, with: "jpg"),
                mediaType: "image/jpeg",
                extension: "jpg"
            )
            #else
            throw AttachmentError.unsupportedType(fileName: safeName)
            #endif
        }
        if data.starts(with: Data("%PDF-".utf8)) {
            return PreparedAttachmentContent(
                data: data,
                fileName: Self.replacingExtension(of: safeName, with: "pdf"),
                mediaType: "application/pdf",
                kind: .pdf,
                fileExtension: "pdf"
            )
        }
        if Self.isAllowedText(name: safeName),
           !data.contains(0),
           String(data: data, encoding: .utf8) != nil
        {
            return PreparedAttachmentContent(
                data: data,
                fileName: safeName,
                mediaType: Self.textMediaType(
                    extension: URL(fileURLWithPath: safeName).pathExtension,
                    declared: declaredMediaType
                ),
                kind: .plainText,
                fileExtension: Self.safeTextExtension(safeName)
            )
        }
        throw AttachmentError.unsupportedType(fileName: safeName)
    }

    public func extractText(
        from attachment: MessageAttachment,
        data: Data,
        maximumCharacters: Int
    ) throws -> String {
        switch attachment.kind {
        case .image:
            throw AttachmentError.extractionFailed(fileName: Self.safeName(attachment.fileName))
        case .plainText:
            guard let text = String(data: data, encoding: .utf8) else {
                throw AttachmentError.extractionFailed(fileName: Self.safeName(attachment.fileName))
            }
            guard text.count <= maximumCharacters else {
                throw AttachmentError.extractedTextTooLarge(
                    fileName: Self.safeName(attachment.fileName),
                    limit: maximumCharacters
                )
            }
            return text
        case .pdf:
            #if canImport(PDFKit)
            guard let document = PDFDocument(data: data),
                  document.pageCount > 0,
                  document.pageCount <= maximumPDFPages
            else {
                throw AttachmentError.extractionFailed(fileName: Self.safeName(attachment.fileName))
            }
            var text = ""
            for index in 0..<document.pageCount {
                guard let pageText = document.page(at: index)?.string else { continue }
                if !text.isEmpty { text.append("\n\n") }
                text.append(pageText)
                guard text.count <= maximumCharacters else {
                    throw AttachmentError.extractedTextTooLarge(
                        fileName: Self.safeName(attachment.fileName),
                        limit: maximumCharacters
                    )
                }
            }
            return text
            #else
            throw AttachmentError.extractionFailed(fileName: Self.safeName(attachment.fileName))
            #endif
        }
    }

    private func image(
        _ data: Data,
        name: String,
        mediaType: String,
        extension fileExtension: String
    ) -> PreparedAttachmentContent {
        PreparedAttachmentContent(
            data: data,
            fileName: Self.replacingExtension(of: name, with: fileExtension),
            mediaType: mediaType,
            kind: .image,
            fileExtension: fileExtension
        )
    }

    private static func safeName(_ value: String) -> String {
        let leaf = value.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init) ?? "Attachment"
        let trimmed = leaf.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Attachment" : String(trimmed.prefix(160))
    }

    private static func replacingExtension(of name: String, with value: String) -> String {
        let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        return (stem.isEmpty ? "Attachment" : stem) + "." + value
    }

    private static func isJPEG(_ data: Data) -> Bool {
        data.count >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
    }

    private static func isPNG(_ data: Data) -> Bool {
        data.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    private static func isGIF(_ data: Data) -> Bool {
        data.starts(with: Data("GIF87a".utf8)) || data.starts(with: Data("GIF89a".utf8))
    }

    private static func isWebP(_ data: Data) -> Bool {
        data.count >= 12
            && data.subdata(in: 0..<4) == Data("RIFF".utf8)
            && data.subdata(in: 8..<12) == Data("WEBP".utf8)
    }

    private static func isHEIF(_ data: Data) -> Bool {
        guard data.count >= 12,
              data.subdata(in: 4..<8) == Data("ftyp".utf8),
              let brand = String(data: data.subdata(in: 8..<12), encoding: .ascii)
        else {
            return false
        }
        return ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand)
    }

    private static let allowedTextExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "xml", "yaml", "yml",
        "html", "htm", "css", "js", "ts", "swift", "py", "rb", "go", "rs",
        "java", "kt", "c", "h", "cpp", "hpp", "sh", "log"
    ]

    private static func isAllowedText(name: String) -> Bool {
        allowedTextExtensions.contains(
            URL(fileURLWithPath: name).pathExtension.lowercased()
        )
    }

    private static func safeTextExtension(_ name: String) -> String {
        let value = URL(fileURLWithPath: name).pathExtension.lowercased()
        return allowedTextExtensions.contains(value) ? value : "txt"
    }

    private static func textMediaType(extension value: String, declared: String?) -> String {
        switch value.lowercased() {
        case "csv": return "text/csv"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html", "htm": return "text/html"
        case "md", "markdown": return "text/markdown"
        default:
            if let declared, declared.lowercased().hasPrefix("text/") {
                return declared.lowercased()
            }
            return "text/plain"
        }
    }

    private static func mediaType(for url: URL) -> String? {
        #if canImport(UniformTypeIdentifiers)
        return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
        #else
        return nil
        #endif
    }
}
