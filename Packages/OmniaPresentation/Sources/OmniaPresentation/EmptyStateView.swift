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
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        description: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

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
            if let actionTitle, let action {
                OmniaButton(
                    title: actionTitle,
                    systemImage: "plus",
                    action: action
                )
                .padding(.top, OmniaTheme.Spacing.sm)
            }
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
