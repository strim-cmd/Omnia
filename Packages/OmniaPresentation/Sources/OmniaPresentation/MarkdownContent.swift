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
        /// A fenced code block; the content and whitespace are preserved.
        case codeBlock(content: String)
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
            case .codeBlock(let content):
                return content
            }
        }.joined(separator: " ")
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
        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if var buffer = codeLines {
                if isClosingFence(line) {
                    segments.append(.codeBlock(content: buffer.joined(separator: "\n")))
                    codeLines = nil
                } else {
                    buffer.append(line)
                    codeLines = buffer
                }
            } else if isOpeningFence(line) {
                let text = textLines.joined(separator: "\n")
                if !text.isEmpty {
                    segments.append(.text(text))
                }
                textLines = []
                codeLines = []
            } else {
                textLines.append(line)
            }
        }
        if let buffer = codeLines {
            segments.append(.codeBlock(content: buffer.joined(separator: "\n")))
        }
        let trailingText = textLines.joined(separator: "\n")
        if !trailingText.isEmpty {
            segments.append(.text(trailingText))
        }
        return segments
    }

    /// Returns whether `line` opens a fenced code block: a run of three or
    /// more backticks, optionally followed by a language identifier.
    private static func isOpeningFence(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0.isWhitespace })
        let backticks = trimmed.prefix(while: { $0 == "`" })
        return backticks.count >= 3
    }

    /// Returns whether `line` closes a fenced code block: a run of three or
    /// more backticks followed by nothing but whitespace.
    private static func isClosingFence(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0.isWhitespace })
        let backticks = trimmed.prefix(while: { $0 == "`" })
        return backticks.count >= 3 && trimmed.dropFirst(backticks.count).allSatisfy { $0.isWhitespace }
    }
}
