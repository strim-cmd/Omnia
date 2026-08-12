#if canImport(SwiftUI)

import Foundation
import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of `MarkdownContent` with native Apple APIs only
/// (DES-012 §3.3.1, ARC-009): prose text segments are rendered as Markdown
/// through Foundation `AttributedString` parsing, and fenced code blocks are
/// presented as distinct code-block elements — system monospaced body text, a
/// platform-resolved background, and preserved whitespace and wrapping — with
/// fixed presentation metrics (a 16pt inset and a 12pt continuous corner
/// radius) and without language-aware syntax coloring. No third-party Markdown
/// renderer or syntax-highlighting library is used (PRODUCT_CHARTER,
/// no-third-party-packages non-goal).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct MarkdownView: View {
    /// The markdown content to render.
    public let content: MarkdownContent

    /// Creates a markdown view over the given content.
    public init(content: MarkdownContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(content.segments.indices, id: \.self) { index in
                segment(content.segments[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func segment(_ segment: MarkdownContent.Segment) -> some View {
        switch segment {
        case .text(let text):
            Text(attributed(text))
                .fixedSize(horizontal: false, vertical: true)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(OmniaTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(codeBlockBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
        }
    }

    private func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    /// The code-block background, resolved per platform: the grouped
    /// background of the system on iOS, the text background on macOS.
    private var codeBlockBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

#endif
