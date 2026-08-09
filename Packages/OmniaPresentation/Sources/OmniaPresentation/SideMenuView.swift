#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The navigation drawer of the shell (new_design.md §7): a slide-in panel over
/// the conversation list that routes between the conversations and settings
/// surfaces. The drawer renders the current route as the selected row and
/// translates the row intents to callbacks; it owns no business logic (ARC-002).
///
/// The panel is a light elevated surface on the same tokens as the rest of the
/// interface — the brand header, the navigation rows, and the provider-count
/// badge the settings row carries (new_design.md §7). Selection state is
/// rendered from the frozen `NavigationState.Route` of the shell (ARC-007).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 16.0, macOS 13.0, *)
public struct SideMenuView: View {
    /// The name of the workspace the drawer presents as the product context.
    public let workspaceName: String
    /// The number of configured provider connections, presented as the badge of
    /// the settings row (new_design.md §7).
    public let providerCount: Int
    /// The current route of the navigation structure: the row of the active
    /// destination is rendered as selected (DES-012 §3.5).
    public let currentRoute: NavigationState.Route
    /// Translates the open-conversations intent: the shell routes to the
    /// conversation list.
    public let onOpenConversations: () -> Void
    /// Translates the open-settings intent: the shell routes to the settings
    /// surface.
    public let onOpenSettings: () -> Void

    /// Creates the navigation drawer over the given context and intent
    /// callbacks.
    public init(
        workspaceName: String,
        providerCount: Int,
        currentRoute: NavigationState.Route,
        onOpenConversations: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.workspaceName = workspaceName
        self.providerCount = providerCount
        self.currentRoute = currentRoute
        self.onOpenConversations = onOpenConversations
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            brand
            Spacer()
                .frame(height: OmniaTheme.Spacing.xxl)
            navRow(
                icon: "bubble.left.and.bubble.right",
                title: Localized.conversations,
                selected: isConversationsSelected,
                count: nil,
                action: onOpenConversations
            )
            navRow(
                icon: "gearshape",
                title: Localized.settings,
                selected: isSettingsSelected,
                count: providerCount,
                action: onOpenSettings
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OmniaTheme.Spacing.xl)
        .padding(.top, OmniaTheme.Spacing.lg)
        .padding(.bottom, OmniaTheme.Spacing.lg)
        .frame(width: 292, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(OmniaTheme.Colors.surface.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(OmniaTheme.Colors.border.opacity(0.5))
                .frame(width: 0.5)
        }
        .shadow(color: OmniaTheme.Shadows.card, radius: 24, x: 8, y: 0)
    }

    private var isConversationsSelected: Bool {
        currentRoute == .conversationList
    }

    private var isSettingsSelected: Bool {
        currentRoute == .settings
    }

    /// The brand header of the drawer: the product monogram over the accent
    /// gradient and the workspace name as the product context (new_design.md
    /// §7).
    private var brand: some View {
        HStack(spacing: OmniaTheme.Spacing.md) {
            Text("O")
                .font(OmniaTheme.Typography.largeTitle)
                .foregroundStyle(Color.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [
                            OmniaTheme.Colors.userBubbleStart,
                            OmniaTheme.Colors.userBubbleEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Omnia")
                    .font(OmniaTheme.Typography.sectionTitle)
                    .foregroundStyle(OmniaTheme.Colors.textPrimary)
                Text(workspaceName)
                    .font(OmniaTheme.Typography.caption)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A navigation row of the drawer: the icon, the title, the selection
    /// highlight, and the optional count badge (new_design.md §7).
    private func navRow(
        icon: String,
        title: String,
        selected: Bool,
        count: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: OmniaTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? OmniaTheme.Colors.accent : OmniaTheme.Colors.textSecondary)
                    .frame(width: 22)
                Text(title)
                    .font(OmniaTheme.Typography.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? OmniaTheme.Colors.textPrimary : OmniaTheme.Colors.textSecondary)
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)")
                        .font(OmniaTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.accent)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(OmniaTheme.Colors.accentSubtle, in: Capsule())
                }
            }
            .padding(.horizontal, OmniaTheme.Spacing.md)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous))
            .background(
                selected
                    ? OmniaTheme.Colors.accentSubtle
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#endif
