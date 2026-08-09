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
            .font(OmniaTheme.Typography.body)
            .foregroundStyle(Color.white)
            .padding(OmniaTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, OmniaTheme.Spacing.lg)
            .accessibilityLabel(Text(message))
    }

    private var backgroundColor: Color {
        .red
    }
}

#endif
