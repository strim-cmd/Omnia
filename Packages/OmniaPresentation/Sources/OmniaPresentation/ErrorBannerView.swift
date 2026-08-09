#if canImport(SwiftUI)

import SwiftUI

/// A shared error banner view for presenting failure and warning messages across
/// presentation views (UX audit V2).
///
/// Consolidates identical banner markup across `ConversationListView`,
/// `SettingsView`, and `ConversationScreenView`.
struct ErrorBannerView: View {
    let message: String
    var systemImage: String = "exclamationmark.triangle"
    var backgroundColor: Color = .red

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.container))
            .overlay(
                RoundedRectangle(cornerRadius: OmniaTheme.Radii.container)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, OmniaTheme.Spacing.l)
            .accessibilityLabel(Text(message))
    }
}

#endif
