#if canImport(SwiftUI)

import SwiftUI

/// A thin, circular icon button of the Omnia design system — the compact
/// affordance of the top bar, the composer, and the message actions
/// (new_design.md §16). Thin SF Symbols at a consistent size.
struct OmniaIconButton: View {
    /// The SF Symbol of the button.
    let systemImage: String
    /// The tint of the symbol.
    var tint: Color = OmniaTheme.Colors.textPrimary
    /// The size of the circular hit area.
    var size: CGFloat = 34
    /// An optional circular fill behind the symbol.
    var background: Color?
    /// Translates the button's intent.
    let action: () -> Void

    /// Creates a circular icon button with the given symbol, tint, size,
    /// optional fill, and action.
    init(
        systemImage: String,
        tint: Color = OmniaTheme.Colors.textPrimary,
        size: CGFloat = 34,
        background: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
        self.background = background
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(tint)
                .background(background ?? Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#endif
