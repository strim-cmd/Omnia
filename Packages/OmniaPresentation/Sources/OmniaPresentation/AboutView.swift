#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the about surface (new_design.md §8): the Omnia
/// branding — the product monogram over the brand gradient and the product
/// name — over the same design system as the rest of the interface. The view
/// renders state and translates intent; it owns no business logic (ARC-002).
///
/// The screen presents only real existing data: the workspace context the shell
/// owns. It renders no version/build information because the application state
/// carries none — the interface is honest (ARC-001).
///
/// The screen is reached from the navigation drawer; the navigation container's
/// system back behavior remains — the system bar chrome is hidden exactly like
/// the conversation list's, so the custom top bar is the only top chrome
/// (navigation is owned by the shell, CHAT.md). The top bar follows the
/// pushed-screen pattern: the leading menu affordance opens the navigation
/// drawer, and the trailing glyph is decorative.
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
@available(iOS 15.0, macOS 12.0, *)
public struct AboutView: View {
    /// The name of the workspace the app presents (new_design.md §8).
    public let workspaceName: String
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void

    /// Creates an about view over the given workspace context.
    public init(workspaceName: String, onOpenMenu: @escaping () -> Void) {
        self.workspaceName = workspaceName
        self.onOpenMenu = onOpenMenu
    }

    public var body: some View {
        ZStack(alignment: .top) {
            OmniaBackground()

            VStack(spacing: 0) {
                customTopBar
                ScrollView {
                    brand
                        .padding(.vertical, OmniaTheme.Spacing.xl)
                }
            }
        }
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #else
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The custom top bar of the screen: the menu button, the title, and the
    /// about glyph (new_design.md §8). The menu affordance opens the navigation
    /// drawer, owned by the shell; the trailing glyph is decorative (CHAT.md).
    private var customTopBar: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: onOpenMenu)
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(Localized.about)
                .font(OmniaTheme.Typography.screenTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            OmniaIconButton(systemImage: "info.circle", size: 36, action: {})
                .accessibilityLabel(Text(Localized.about))
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
        .background(OmniaTheme.Colors.background.opacity(0.8))
    }

    /// The brand block of the screen: the product monogram over the accent
    /// gradient, the product name, and the workspace context (new_design.md §8,
    /// COMPONENTS.md — Logo).
    private var brand: some View {
        VStack(spacing: OmniaTheme.Spacing.md) {
            Text("O")
                .font(OmniaTheme.Typography.largeTitle)
                .foregroundStyle(Color.white)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [
                            OmniaTheme.Colors.userBubbleStart,
                            OmniaTheme.Colors.userBubbleEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.large, style: .continuous)
                )
            Text("Omnia")
                .font(OmniaTheme.Typography.largeTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
            Text(workspaceName)
                .font(OmniaTheme.Typography.caption)
                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#endif
