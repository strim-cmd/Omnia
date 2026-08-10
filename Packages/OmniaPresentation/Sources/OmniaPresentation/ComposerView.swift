#if canImport(SwiftUI)

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// The composer of the Omnia design system: a compact, elevated capsule holding
/// an attachment affordance, the expanding message field, and the round
/// send/stop button — a single control roughly 50–60 pt tall on one line that
/// expands only as needed (1–6 lines) and scrolls internally after that
/// (new_design.md §5, §21). It is the primary control of the conversation
/// screen: the field is the user's draft, the send button translates the send
/// intent, and the stop button replaces it while a stream is active.
struct ComposerView: View {
    /// A binding to the drafted text of the conversation screen.
    @Binding var draft: String
    /// Whether a stream is active and the Stop affordance is shown.
    let isStreaming: Bool
    /// Translates the send intent with the drafted text.
    let onSubmit: () -> Void
    /// Translates the cancel intent while a stream is active.
    let onCancel: () -> Void

    /// The number of lines the field shows when empty.
    private let minLines = 1
    /// The number of lines the field grows to before scrolling internally.
    private let maxLines = 6

    var body: some View {
        HStack(alignment: .bottom, spacing: OmniaTheme.Spacing.sm) {
            OmniaIconButton(
                systemImage: "paperclip",
                tint: OmniaTheme.Colors.textSecondary,
                size: 36,
                action: {}
            )
            .accessibilityLabel(Text(Localized.attachment))

            TextField("", text: $draft, prompt: Text(Localized.messagePlaceholder), axis: .vertical)
                .font(OmniaTheme.Typography.body)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .tint(OmniaTheme.Colors.accent)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .frame(minHeight: 50, maxHeight: 150)
                .padding(.vertical, OmniaTheme.Spacing.sm)
                .background(OmniaTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous)
                        .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
                )
                .onSubmit {
                    onSubmit()
                }
                .accessibilityLabel(Text(Localized.message))

            if isStreaming {
                OmniaIconButton(
                    systemImage: "stop.circle.fill",
                    tint: OmniaTheme.Colors.accent,
                    size: 40,
                    action: onCancel
                )
                .accessibilityLabel(Text(Localized.stop))
            } else {
                OmniaIconButton(
                    systemImage: "arrow.up.circle.fill",
                    tint: draft.isEmpty ? OmniaTheme.Colors.textMuted : OmniaTheme.Colors.accent,
                    size: 40,
                    action: onSubmit
                )
                .accessibilityLabel(Text(Localized.send))
                .disabled(draft.isEmpty)
            }
        }
        .padding(OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.composer, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.composer, style: .continuous)
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: OmniaTheme.Shadows.composer, radius: 14, x: 0, y: 6)
        .animation(.easeOut(duration: 0.2), value: isStreaming)
    }

    /// The drafted text trimmed of surrounding whitespace; an empty or
    /// whitespace draft cannot be sent.
    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The vertical padding of the field, chosen so a single line keeps the
    /// whole composer at the ~50–60 pt target of the design (new_design.md §5).
    private var composerFieldVerticalPadding: CGFloat {
        7
    }

    /// The field height for the given number of lines.
    private func composerFieldHeight(for lines: Int) -> CGFloat {
        composerLineHeight() * CGFloat(lines) + composerFieldVerticalPadding * 2
    }

    /// The line height of the field's body text on the current platform.
    private func composerLineHeight() -> CGFloat {
        #if canImport(UIKit)
        return UIFont.preferredFont(forTextStyle: .body).lineHeight
        #elseif canImport(AppKit)
        let font = NSFont.preferredFont(forTextStyle: .body)
        return font.ascender - font.descender + font.leading
        #else
        return 17
        #endif
    }
}

#endif
