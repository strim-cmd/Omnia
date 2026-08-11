#if canImport(SwiftUI)

import SwiftUI

/// A shared error banner view for presenting failure and warning messages across
/// presentation views (UX audit V2).
///
/// Consolidates identical banner markup across `ConversationListView`,
/// `SettingsView`, and `ConversationScreenView`.
struct ErrorBannerView: View {
    let message: String
    var title: String? = nil
    var systemImage: String = "exclamationmark.triangle"
    var backgroundColor: Color = OmniaTheme.Colors.errorSubtle
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.error)
            VStack(alignment: .leading, spacing: OmniaTheme.Spacing.xs) {
                if let title {
                    Text(title)
                        .font(OmniaTheme.Typography.secondary.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textPrimary)
                }
                Text(message)
                    .font(OmniaTheme.Typography.body)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
            }
            if let onRetry {
                Spacer(minLength: OmniaTheme.Spacing.sm)
                OmniaButton(
                    title: Localized.retry,
                    systemImage: "arrow.clockwise",
                    style: .secondary,
                    action: onRetry
                )
            }
        }
        .padding(OmniaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                .stroke(OmniaTheme.Colors.error.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .accessibilityLabel(Text(message))
    }
}

#endif
