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
                ? AnyShapeStyle(Color.accentColor.gradient)
                : AnyShapeStyle(Material.thin.opacity(0.8))
        )
        .foregroundColor(message.role == .user ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
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
