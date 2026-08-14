#if canImport(SwiftUI)

import Foundation
import OmniaApplication
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    @State private var copiedCodeIndex: Int?

    /// Creates a markdown view over the given content.
    public init(content: MarkdownContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(content.blocks.indices, id: \.self) { index in
                block(content.blocks[index], index: index)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func block(_ block: MarkdownContent.Block, index: Int) -> some View {
        switch block {
        case .paragraph(let text):
            Text(attributed(text))
                .fixedSize(horizontal: false, vertical: true)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
        case .heading(let level, let text):
            Text(attributed(text))
                .font(headingFont(level))
                .textSelection(.enabled)
        case .unorderedListItem(let text):
            listItem(marker: "•", text: text)
        case .orderedListItem(let number, let text):
            listItem(marker: "\(number).", text: text)
        case .blockQuote(let text):
            HStack(alignment: .top, spacing: OmniaTheme.Spacing.sm) {
                Rectangle()
                    .fill(OmniaTheme.Colors.border)
                    .frame(width: 3)
                Text(attributed(text))
                    .font(.body.italic())
                    .textSelection(.enabled)
            }
        case .horizontalRule:
            Divider()
        case .codeBlock(let code, let language):
            codeBlock(code, language: language, index: index)
        }
    }

    private func listItem(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: OmniaTheme.Spacing.sm) {
            Text(marker)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            Text(attributed(text))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, OmniaTheme.Spacing.sm)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.bold)
        case 3: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }

    private func codeBlock(_ code: String, language: String?, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: OmniaTheme.Spacing.sm) {
                Text(language ?? Localized.code)
                    .font(OmniaTheme.Typography.caption)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
                Spacer()
                Button {
                    copyCode(code, index: index)
                } label: {
                    Label(
                        copiedCodeIndex == index ? Localized.copied : Localized.copyCode,
                        systemImage: copiedCodeIndex == index ? "checkmark" : "doc.on.doc"
                    )
                    .font(OmniaTheme.Typography.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(Localized.copyCodeHint))
            }
            .padding(.horizontal, OmniaTheme.Spacing.md)
            .padding(.vertical, OmniaTheme.Spacing.sm)
            Divider()
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(OmniaTheme.Spacing.lg)
            }
        }
        .background(codeBlockBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func copyCode(_ code: String, index: Int) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        copiedCodeIndex = index
    }

    private func attributed(_ text: String) -> AttributedString {
        var rendered = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        let unsafeRanges = rendered.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard let link = run.link else { return nil }
            guard let scheme = link.scheme?.lowercased() else { return run.range }
            return ["http", "https", "mailto"].contains(scheme) ? nil : run.range
        }
        for range in unsafeRanges {
            rendered[range].link = nil
        }
        return rendered
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
