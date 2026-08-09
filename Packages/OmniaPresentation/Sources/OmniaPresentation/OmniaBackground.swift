#if canImport(SwiftUI)

import SwiftUI

/// The root background of the Omnia design system: a subtle, near-black navy
/// gradient with a whisper of the surface color at the top, so the interface
/// reads as a single premium surface rather than flat color (new_design.md §1).
/// In light theme it resolves to a soft near-white gradient — the light theme
/// is a real theme, not an inversion (new_design.md §13).
struct OmniaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                OmniaTheme.Colors.surface,
                OmniaTheme.Colors.background,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#endif
