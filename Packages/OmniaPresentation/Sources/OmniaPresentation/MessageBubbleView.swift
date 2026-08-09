#if canImport(SwiftUI)

import SwiftUI
import OmniaApplication

/// A polished, modern message bubble for chat conversations (UI Redesign).
///
/// Consolidates message bubble styling and accessibility logic (A3).
struct MessageBubbleView: View {
    let message: MessagePresentation
    let roleLabel: String
    var caption: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let content = message.content {
                MarkdownView(content: content)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            message.role == .user
                ? AnyShapeStyle(OmniaTheme.Colors.accentPurple.gradient)
                : AnyShapeStyle(OmniaTheme.Colors.surface)
        )
        .foregroundColor(message.role == .user ? .white : OmniaTheme.Colors.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.bubble, style: .continuous)
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: OmniaTheme.Shadows.bubble, radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
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
