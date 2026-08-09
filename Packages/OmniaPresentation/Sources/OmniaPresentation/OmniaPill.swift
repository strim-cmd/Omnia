#if canImport(SwiftUI)

import SwiftUI

/// A compact, elevated capsule of the Omnia design system — the container of
/// the provider selector, the search field, the status pills, and small
/// controls (new_design.md §5, §6, §16). A small optional status dot leads the
/// content (green for the ready provider, the design's success state).
struct OmniaPill<Content: View>: View {
    /// The color of the leading status dot, or `nil` for no dot.
    let dotColor: Color?
    /// The capsule content.
    let content: Content

    /// Creates a pill with an optional leading status dot and the given
    /// content.
    init(
        dotColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.dotColor = dotColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }
            content
        }
        .font(OmniaTheme.Typography.secondary)
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.elevatedSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: OmniaTheme.Shadows.card, radius: 8, x: 0, y: 2)
    }
}

#endif
