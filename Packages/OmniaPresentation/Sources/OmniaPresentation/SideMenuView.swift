#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The navigation drawer of the shell (new_design.md §8): a slide-in panel over
/// the conversation list that routes between the conversations, providers,
/// settings, and about surfaces, and translates the new-chat intent of the
/// conversation list. The drawer renders the current route as the selected row
/// and translates the row intents to callbacks; it owns no business logic
/// (ARC-002).
///
/// The panel is a light elevated surface on the same tokens as the rest of the
/// interface — the brand header, the navigation rows, and the compact Dark Mode
/// card the bottom area carries (new_design.md §8, COMPONENTS.md — ThemeToggle).
/// Selection state is rendered from the frozen `NavigationState.Route` of the
/// shell (ARC-007): the providers and settings rows present the same existing
/// destination, so both render as selected when the settings route is active.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 16.0, macOS 13.0, *)
public struct SideMenuView: View {
    /// The name of the workspace the drawer presents as the product context.
    public let workspaceName: String
    /// The number of configured provider connections, presented as the badge of
    /// the providers row (new_design.md §8).
    public let providerCount: Int
    /// The current route of the navigation structure: the row of the active
    /// destination is rendered as selected (DES-012 §3.5).
    public let currentRoute: NavigationState.Route
    /// Whether the shell forces the dark color scheme: presented as the drawer's
    /// Dark Mode toggle (COMPONENTS.md — ThemeToggle).
    @Binding public var isDarkMode: Bool
    /// Translates the new-chat intent: the shell returns to the conversation
    /// list and creates a fresh conversation.
    public let onNewChat: () -> Void
    /// Translates the open-conversations intent: the shell routes to the
    /// conversation list.
    public let onOpenConversations: () -> Void
    /// Translates the open-providers intent: the shell routes to the providers
    /// surface.
    public let onOpenProviders: () -> Void
    /// Translates the open-settings intent: the shell routes to the settings
    /// surface.
    public let onOpenSettings: () -> Void
    /// Translates the open-about intent: the shell routes to the about surface.
    public let onOpenAbout: () -> Void

    /// Creates the navigation drawer over the given context and intent
    /// callbacks.
    public init(
        workspaceName: String,
        providerCount: Int,
        currentRoute: NavigationState.Route,
        isDarkMode: Binding<Bool>,
        onNewChat: @escaping () -> Void,
        onOpenConversations: @escaping () -> Void,
        onOpenProviders: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenAbout: @escaping () -> Void
    ) {
        self.workspaceName = workspaceName
        self.providerCount = providerCount
        self.currentRoute = currentRoute
        self._isDarkMode = isDarkMode
        self.onNewChat = onNewChat
        self.onOpenConversations = onOpenConversations
        self.onOpenProviders = onOpenProviders
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
    }

    public var body: some View {
        VStack(spacing: 0) {
            brand
            Spacer()
                .frame(height: OmniaTheme.Spacing.xxl)
            navRow(
                icon: "square.and.pencil",
                title: Localized.newChat,
                selected: false,
                count: nil,
                action: onNewChat
            )
            navRow(
                icon: "bubble.left.and.bubble.right",
                title: Localized.conversations,
                selected: isConversationsSelected,
                count: nil,
                action: onOpenConversations
            )
            navRow(
                icon: "bolt.circle",
                title: Localized.providers,
                selected: isProvidersSelected,
                count: providerCount,
                action: onOpenProviders
            )
            navRow(
                icon: "gearshape",
                title: Localized.settings,
                selected: isSettingsSelected,
                count: nil,
                action: onOpenSettings
            )
            navRow(
                icon: "info.circle",
                title: Localized.about,
                selected: isAboutSelected,
                count: nil,
                action: onOpenAbout
            )
            Spacer(minLength: OmniaTheme.Spacing.lg)
            footer
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

    private var isProvidersSelected: Bool {
        currentRoute == .settings
    }

    private var isSettingsSelected: Bool {
        currentRoute == .settings
    }

    private var isAboutSelected: Bool {
        currentRoute == .about
    }

    /// The brand header of the drawer: the product monogram over the accent
    /// gradient and the workspace name as the product context (new_design.md
    /// §8).
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
    /// highlight, and the optional count badge (new_design.md §8).
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

    /// The bottom area of the drawer: the separator over the compact Dark Mode
    /// card (new_design.md §8, COMPONENTS.md — ThemeToggle).
    private var footer: some View {
        VStack(spacing: OmniaTheme.Spacing.md) {
            Rectangle()
                .fill(OmniaTheme.Colors.border.opacity(0.5))
                .frame(height: 0.5)
            darkModeToggle
        }
    }

    /// The compact Dark Mode card of the drawer: the moon icon, the label, and
    /// the toggle control (new_design.md §8, COMPONENTS.md — ThemeToggle). The
    /// toggle drives the shell's preferred color scheme; it is never persisted
    /// and owns no state beyond the presented binding (ARC-002).
    private var darkModeToggle: some View {
        HStack(spacing: OmniaTheme.Spacing.md) {
            Image(systemName: "moon")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                .frame(width: 22)
            Text(Localized.darkMode)
                .font(OmniaTheme.Typography.body)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
            Spacer(minLength: 0)
            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
                .tint(OmniaTheme.Colors.accent)
                .accessibilityLabel(Text(Localized.darkMode))
        }
        .padding(.horizontal, OmniaTheme.Spacing.md)
        .padding(.vertical, 10)
        .background(
            OmniaTheme.Colors.elevatedSurface,
            in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
                .stroke(OmniaTheme.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

#endif
