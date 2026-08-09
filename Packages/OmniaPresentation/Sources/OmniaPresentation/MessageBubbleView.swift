#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// A polished, modern message bubble for chat conversations (UI Redesign V3).
///
/// The user bubble is a vivid purple gradient surface with white text and a
/// compact presence; the assistant bubble is a quiet elevated surface with a
/// subtle border and a soft shadow. The assistant bubble carries a compact,
/// unobtrusive action row — copy, like, dislike, more — beneath it
/// (new_design.md §5). Bubbles never span the full width of a large display.
///
/// Consolidates message bubble styling and accessibility logic (A3): each
/// bubble is one logical VoiceOver element combining the role, the
/// interruption status when present, and the content (UX audit A3).
struct MessageBubbleView: View {
    /// The message the bubble presents.
    let message: MessagePresentation
    /// The localized role label of the message.
    let roleLabel: String
    /// An optional interruption caption the bubble presents.
    var caption: String? = nil
    /// Whether the assistant bubble's compact action row is shown.
    var showsActions = false
    /// Whether the like action is active.
    var isLiked = false
    /// Whether the dislike action is active.
    var isDisliked = false
    /// Translates the copy action with the message's plain text.
    var onCopy: () -> Void = {}
    /// Translates the like action.
    var onToggleLike: () -> Void = {}
    /// Translates the dislike action.
    var onToggleDislike: () -> Void = {}

    /// Creates a message bubble for the given presentation and role label,
    /// with the optional interruption caption and the optional assistant
    /// action row.
    init(
        message: MessagePresentation,
        roleLabel: String,
        caption: String? = nil,
        showsActions: Bool = false,
        isLiked: Bool = false,
        isDisliked: Bool = false,
        onCopy: @escaping () -> Void = {},
        onToggleLike: @escaping () -> Void = {},
        onToggleDislike: @escaping () -> Void = {}
    ) {
        self.message = message
        self.roleLabel = roleLabel
        self.caption = caption
        self.showsActions = showsActions
        self.isLiked = isLiked
        self.isDisliked = isDisliked
        self.onCopy = onCopy
        self.onToggleLike = onToggleLike
        self.onToggleDislike = onToggleDislike
    }

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.sm) {
            bubbleBody
            if showsActions && !isUser {
                actionsRow
            }
        }
    }

    private var bubbleBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let content = message.content {
                MarkdownView(content: content)
            }
            if let caption {
                Text(caption)
                    .font(OmniaTheme.Typography.caption)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            }
        }
        .padding(OmniaTheme.Spacing.lg)
        .frame(maxWidth: OmniaTheme.maxBubbleWidth, alignment: .leading)
        .background(bubbleBackground)
        .foregroundColor(bubbleTextColor)
        .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous))
        .overlay {
            if !isUser {
                RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous)
                    .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
            }
        }
        .shadow(color: OmniaTheme.Shadows.bubble, radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    /// The compact action row of the assistant bubble — copy, like, dislike,
    /// more — small, thin SF Symbols that appear unobtrusively (new_design.md
    /// §5).
    private var actionsRow: some View {
        HStack(spacing: OmniaTheme.Spacing.xs) {
            actionButton(
                systemImage: "doc.on.doc",
                isActive: false,
                accessibilityLabel: Localized.copy
            ) {
                onCopy()
            }
            actionButton(
                systemImage: "hand.thumbsup",
                isActive: isLiked,
                accessibilityLabel: Localized.like
            ) {
                onToggleLike()
            }
            actionButton(
                systemImage: "hand.thumbsdown",
                isActive: isDisliked,
                accessibilityLabel: Localized.dislike
            ) {
                onToggleDislike()
            }
            actionButton(
                systemImage: "ellipsis",
                isActive: false,
                accessibilityLabel: Localized.more
            ) {}
        }
        .padding(.leading, OmniaTheme.Spacing.md)
        .accessibilityLabel(Text(Localized.messageActions))
        .accessibilityElement(children: .contain)
    }

    private func actionButton(
        systemImage: String,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? OmniaTheme.Colors.accent : OmniaTheme.Colors.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    /// The bubble background: a vivid purple gradient for the user, the quiet
    /// elevated surface for the assistant.
    private var bubbleBackground: AnyShapeStyle {
        if isUser {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [OmniaTheme.Colors.userBubbleStart, OmniaTheme.Colors.userBubbleEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(OmniaTheme.Colors.elevatedSurface)
    }

    private var bubbleTextColor: Color {
        isUser ? OmniaTheme.Colors.userBubbleText : OmniaTheme.Colors.textPrimary
    }

    /// The bubble label composed of the role, the interruption status when
    /// present, and the content, so VoiceOver reads the bubble as one logical
    /// element (UX audit A3).
    private var accessibilityLabel: String {
        var parts = [roleLabel]
        if let caption {
            parts.append(caption)
        }
        if let content = message.content {
            let text = content.accessibilityText
            if !text.isEmpty {
                parts.append(text)
            }
        }
        return parts.joined(separator: ", ")
    }
}

#endif
