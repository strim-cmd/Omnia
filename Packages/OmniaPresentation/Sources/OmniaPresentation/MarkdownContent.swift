import Foundation
import OmniaApplication
import OmniaFoundation

/// The ordered content model of a message for the conversation screen:
/// the markdown content of a message as the sequence of its prose text
/// segments and fenced code-block segments (DES-012 §3.1, §3.3.1,
/// Conversation module, ARC-007).
///
/// `MarkdownContent` is the single content model for assistant messages
/// (DES-012 §3.1). Segmenting fenced code blocks is deterministic
/// presentation logic, testable on the Linux build environment (§3.7); the
/// Apple-platform view layer renders the segments with native Apple APIs only
/// — Foundation `AttributedString` Markdown parsing and native SwiftUI/TextKit
/// rendering — never a third-party renderer (§3.3.1).
///
/// The value type is immutable, equal by content, `Equatable` and `Sendable`,
/// and owns no business logic (ARC-002, ARC-003).
public struct MarkdownContent: Equatable, Sendable {
    /// A content segment of a message (DES-012 §3.3.1).
    public enum Segment: Equatable, Sendable {
        /// Prose text, rendered as Markdown by the view layer.
        case text(String)
        /// A fenced code block; content, whitespace, and an optional safe
        /// language label are preserved.
        case codeBlock(content: String, language: String?)
    }

    /// Semantic blocks rendered by the existing native Markdown view.
    public enum Block: Equatable, Sendable {
        case paragraph(String)
        case heading(level: Int, content: String)
        case unorderedListItem(String)
        case orderedListItem(number: Int, content: String)
        case blockQuote(String)
        case horizontalRule
        case codeBlock(content: String, language: String?)
    }

    /// The ordered sequence of the content segments.
    public let segments: [Segment]

    /// Creates markdown content from the given ordered segments.
    public init(segments: [Segment]) {
        self.segments = segments
    }

    /// The plain-text reading of the markdown content: strips inline markdown
    /// segments as the `MarkdownView` renders them (UX audit A3).
    public var accessibilityText: String {
        segments.compactMap { segment in
            switch segment {
            case .text(let text):
                return text
            case .codeBlock(let content, _):
                return content
            }
        }.joined(separator: " ")
    }

    /// Block semantics used for headings, lists, quotes, code, and prose. The
    /// parser is deliberately bounded and deterministic so partial streaming
    /// Markdown always has a renderable fallback.
    public var blocks: [Block] {
        segments.flatMap { segment in
            switch segment {
            case .text(let text): return Self.blocks(from: text)
            case .codeBlock(let content, let language):
                return [.codeBlock(content: content, language: language)]
            }
        }
    }

    /// Code blocks exposed for Copy Code state and deterministic tests.
    public var copyableCodeBlocks: [String] {
        segments.compactMap { segment in
            guard case .codeBlock(let content, _) = segment else { return nil }
            return content
        }
    }

    /// Creates markdown content by deterministically segmenting `markdown`
    /// into prose text segments and fenced code-block segments (§3.3.1).
    ///
    /// A fenced code block is a run of three or more backticks opening a block
    /// and the same closing it; the opening fence may carry a language
    /// identifier, which is not part of the code content and is not rendered
    /// by the platform-independent surface. The code-block content — the lines
    /// between the fences — is preserved exactly, including its whitespace. An
    /// opening fence with no closing fence extends the code block to the end
    /// of the content.
    public init(markdown: String) {
        self.segments = Self.segmented(markdown)
    }

    /// The deterministic fenced-code-block segmentation (§3.3.1).
    private static func segmented(_ markdown: String) -> [Segment] {
        var segments: [Segment] = []
        var textLines: [String] = []
        var codeLines: [String]? = nil
        var codeLanguage: String?
        var codeFenceLength = 3
        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if var buffer = codeLines {
                if isClosingFence(line, minimumLength: codeFenceLength) {
                    segments.append(
                        .codeBlock(
                            content: buffer.joined(separator: "\n"),
                            language: codeLanguage
                        )
                    )
                    codeLines = nil
                    codeLanguage = nil
                } else {
                    buffer.append(line)
                    codeLines = buffer
                }
            } else if let opening = openingFence(line) {
                let text = textLines.joined(separator: "\n")
                if !text.isEmpty {
                    segments.append(.text(text))
                }
                textLines = []
                codeLines = []
                codeLanguage = opening.language
                codeFenceLength = opening.length
            } else {
                textLines.append(line)
            }
        }
        if let buffer = codeLines {
            segments.append(
                .codeBlock(
                    content: buffer.joined(separator: "\n"),
                    language: codeLanguage
                )
            )
        }
        let trailingText = textLines.joined(separator: "\n")
        if !trailingText.isEmpty {
            segments.append(.text(trailingText))
        }
        return segments
    }

    /// Returns whether `line` opens a fenced code block: a run of three or
    /// more backticks, optionally followed by a language identifier.
    private static func openingFence(_ line: String) -> (length: Int, language: String?)? {
        let trimmed = line.drop(while: { $0.isWhitespace })
        let backticks = trimmed.prefix(while: { $0 == "`" })
        guard backticks.count >= 3 else { return nil }
        let rawLanguage = trimmed.dropFirst(backticks.count)
            .trimmingCharacters(in: .whitespaces)
        let language = rawLanguage.isEmpty
            ? nil
            : String(rawLanguage.prefix(32)).filter { $0.isLetter || $0.isNumber || "+#._-".contains($0) }
        return (backticks.count, language?.isEmpty == false ? language : nil)
    }

    /// Returns whether `line` closes a fenced code block: a run of three or
    /// more backticks followed by nothing but whitespace.
    private static func isClosingFence(_ line: String, minimumLength: Int) -> Bool {
        let trimmed = line.drop(while: { $0.isWhitespace })
        let backticks = trimmed.prefix(while: { $0 == "`" })
        return backticks.count >= minimumLength
            && trimmed.dropFirst(backticks.count).allSatisfy { $0.isWhitespace }
    }

    private static func blocks(from text: String) -> [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
            } else if let heading = heading(from: trimmed) {
                flushParagraph()
                result.append(.heading(level: heading.level, content: heading.content))
            } else if let item = orderedListItem(from: trimmed) {
                flushParagraph()
                result.append(.orderedListItem(number: item.number, content: item.content))
            } else if let item = unorderedListItem(from: trimmed) {
                flushParagraph()
                result.append(.unorderedListItem(item))
            } else if let quote = blockQuote(from: trimmed) {
                flushParagraph()
                result.append(.blockQuote(quote))
            } else if isHorizontalRule(trimmed) {
                flushParagraph()
                result.append(.horizontalRule)
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return result
    }

    private static func heading(from line: String) -> (level: Int, content: String)? {
        let markers = line.prefix(while: { $0 == "#" })
        guard (1...6).contains(markers.count) else { return nil }
        let remainder = line.dropFirst(markers.count)
        guard remainder.first?.isWhitespace == true else { return nil }
        let content = remainder.trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : (markers.count, content)
    }

    private static func unorderedListItem(from line: String) -> String? {
        guard let marker = line.first, "-*+".contains(marker) else { return nil }
        let remainder = line.dropFirst()
        guard remainder.first?.isWhitespace == true else { return nil }
        let content = remainder.trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }

    private static func orderedListItem(from line: String) -> (number: Int, content: String)? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty,
              let number = Int(digits),
              let punctuation = line.dropFirst(digits.count).first,
              punctuation == "." || punctuation == ")"
        else {
            return nil
        }
        let remainder = line.dropFirst(digits.count + 1)
        guard remainder.first?.isWhitespace == true else { return nil }
        let content = remainder.trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : (number, content)
    }

    private static func blockQuote(from line: String) -> String? {
        guard line.first == ">" else { return nil }
        let content = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let marker = compact.first, "-*_".contains(marker) else {
            return false
        }
        return compact.allSatisfy { $0 == marker }
    }
}
