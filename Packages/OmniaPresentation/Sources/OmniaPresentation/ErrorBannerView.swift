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
    var backgroundColor: Color = OmniaTheme.Colors.errorSubtle
    var onRetry: (() -> Void)?

    var body: some View {
        HStack {
            Label {
                Text(message)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(OmniaTheme.Colors.error)
            }
            .font(OmniaTheme.Typography.body)

            if let onRetry {
                Spacer()
                Button(action: onRetry) {
                    Text(Localized.retry)
                        .font(OmniaTheme.Typography.caption)
                        .padding(.horizontal, OmniaTheme.Spacing.sm)
                        .padding(.vertical, OmniaTheme.Spacing.xs)
                        .foregroundStyle(OmniaTheme.Colors.error)
                        .background(OmniaTheme.Colors.error.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
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
