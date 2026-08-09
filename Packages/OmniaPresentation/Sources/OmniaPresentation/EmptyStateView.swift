#if canImport(SwiftUI)

import SwiftUI

/// A shared empty-state view for presenting empty conditions across presentation
/// views (UX audit V2).
///
/// Consolidates identical empty-state markup across `ConversationListView` and
/// `SettingsView`.
struct EmptyStateView: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(spacing: OmniaTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(OmniaTheme.Typography.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OmniaTheme.Colors.accent)
            Text(title)
                .font(OmniaTheme.Typography.sectionTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
            Text(description)
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
        }
        .padding(OmniaTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(OmniaTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.card, style: .continuous)
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .padding(OmniaTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

#endif
