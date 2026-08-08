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
                ? Color.accentColor.gradient
                : Material.thin.opacity(0.8).asAnyView()
        )
        .foregroundColor(message.role == .user ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(roleLabel)\(caption != nil ? ", \(caption!)" : ""), \(message.content?.accessibilityText ?? "")"))
    }
}

extension View {
    func asAnyView() -> AnyView {
        AnyView(self)
    }
}

#endif
