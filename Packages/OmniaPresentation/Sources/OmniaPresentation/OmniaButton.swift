#if canImport(SwiftUI)

import SwiftUI

/// The buttons of the Omnia design system: a primary filled accent button, a
/// bordered secondary button, and a subtle destructive variant — rounded and
/// compact (new_design.md §16).
struct OmniaButton: View {
    /// The style of a button.
    enum Style {
        /// The filled accent primary button.
        case primary
        /// The bordered secondary button.
        case secondary
        /// The subtle destructive button.
        case destructive
    }

    /// The button title.
    let title: String
    /// An optional leading SF Symbol.
    let systemImage: String?
    /// The button style.
    let style: Style
    /// Translates the button's intent.
    let action: () -> Void

    /// Creates a button with the given title, optional icon, style, and action.
    init(
        title: String,
        systemImage: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: OmniaTheme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
            }
            .font(OmniaTheme.Typography.body.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, OmniaTheme.Spacing.lg)
            .padding(.vertical, OmniaTheme.Spacing.sm)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return OmniaTheme.Colors.textPrimary
        case .destructive:
            return OmniaTheme.Colors.error
        }
    }

    private var background: Color {
        switch style {
        case .primary:
            return OmniaTheme.Colors.accent
        case .secondary:
            return OmniaTheme.Colors.elevatedSurface
        case .destructive:
            return OmniaTheme.Colors.errorSubtle
        }
    }

    private var border: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return OmniaTheme.Colors.border
        case .destructive:
            return OmniaTheme.Colors.error.opacity(0.3)
        }
    }
}

#endif
