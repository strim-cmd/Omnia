#if canImport(SwiftUI)

import SwiftUI

/// A reusable elevated card of the Omnia design system: the `elevatedSurface`
/// color, a subtle border, a soft shadow, and large rounded corners — the
/// standard surface of the conversation list rows, provider cards, settings
/// sections, and the empty/error states (new_design.md §16).
struct OmniaCard<Content: View>: View {
    /// The corner radius of the card.
    let radius: CGFloat
    /// The inner padding of the card.
    let padding: CGFloat
    /// The card content.
    let content: Content

    /// Creates a card over the given content with the design system's corner
    /// radius and padding.
    init(
        radius: CGFloat = OmniaTheme.Radii.card,
        padding: CGFloat = OmniaTheme.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OmniaTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
            )
            .shadow(color: OmniaTheme.Shadows.card, radius: 12, x: 0, y: 4)
    }
}

#endif
