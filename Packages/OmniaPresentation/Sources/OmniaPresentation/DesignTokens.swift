#if canImport(SwiftUI)

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// The design tokens of the Omnia design system (new_design.md §2, §3, §4,
/// §18): the single semantic source of the colors, radii, spacing, typography,
/// and shadows every presentation view renders through. No view hardcodes a
/// color, radius, or spacing value; the tokens are the one vocabulary.
///
/// Colors are adaptive semantic tokens resolved per the system color scheme
/// through a dynamic `UIColor`/`NSColor` provider: the dark palette is the
/// product's identity (deep navy/black, purple/cyan accents), and the light
/// palette is a real, distinct theme — never a mechanical inversion of the
/// dark one (new_design.md §13). Typography uses the native Dynamic Type text
/// styles, so accessibility sizing is never fixed (new_design.md §3).
///
/// The tokens are the single system the earlier redesigns established
/// (`OmniaTheme`); this redesign extends that system to the full semantic set
/// rather than introducing a second one (new_design.md §2, §16).
public enum OmniaTheme {
    /// The adaptive semantic color palette.
    public enum Colors {
        // MARK: Backgrounds

        /// The primary application background (dark `#050911`, light `#F7F8FA`).
        public static let background = adaptive(light: 0xF7F8FA, dark: 0x050911)
        /// The secondary/elevated surface (dark `#0A0F19`, light `#FFFFFF`).
        public static let surface = adaptive(light: 0xFFFFFF, dark: 0x0A0F19)
        /// The card/elevated surface (dark `#0D1420`, light `#F1F3F7`).
        public static let elevatedSurface = adaptive(light: 0xF1F3F7, dark: 0x0D1420)
        /// The subtle border (dark `#202A3A`, light `#D9DEE8`).
        public static let border = adaptive(light: 0xD9DEE8, dark: 0x202A3A)

        // MARK: Text

        /// Primary text (dark `#F0F2F7`, light `#171A21`).
        public static let textPrimary = adaptive(light: 0x171A21, dark: 0xF0F2F7)
        /// Secondary text (dark `#8D96A8`, light `#667085`).
        public static let textSecondary = adaptive(light: 0x667085, dark: 0x8D96A8)
        /// Muted text (dark `#626B7C`, light `#667085`).
        public static let textMuted = adaptive(light: 0x667085, dark: 0x626B7C)

        // MARK: Accent

        /// The primary accent — vivid purple (dark `#8A2BE2`, light `#7C3AED`).
        public static let accent = adaptive(light: 0x7C3AED, dark: 0x8A2BE2)
        /// The secondary accent — cyan (dark `#00D4FF`, light `#0A84C6`).
        public static let accentSecondary = adaptive(light: 0x0A84C6, dark: 0x00D4FF)
        /// The accent's soft fill (selected rows, subtle highlights).
        public static let accentSubtle = accent.opacity(0.14)
        /// The user message bubble gradient start (vivid purple).
        public static let userBubbleStart = adaptive(light: 0x7C3AED, dark: 0x7C3AED)
        /// The user message bubble gradient end (vivid purple).
        public static let userBubbleEnd = adaptive(light: 0x8A2BE2, dark: 0x8A2BE2)
        /// The text color on the user message bubble — white in both themes.
        public static let userBubbleText = Color.white

        // MARK: Status

        /// Success / active state — green (dark `#22C55E`, light `#15803D`).
        public static let success = adaptive(light: 0x15803D, dark: 0x22C55E)
        /// Warning — amber (dark `#F59E0B`, light `#B45309`).
        public static let warning = adaptive(light: 0xB45309, dark: 0xF59E0B)
        /// Error — red (dark `#EF4444`, light `#DC2626`).
        public static let error = adaptive(light: 0xDC2626, dark: 0xEF4444)
        /// The error's soft fill (destructive actions, error states).
        public static let errorSubtle = error.opacity(0.14)
        /// The warning's soft fill (warning states).
        public static let warningSubtle = warning.opacity(0.14)

        // MARK: Decorative

        /// The soft purple glow of decorative states (empty state, streaming).
        public static let glowPurple = accent.opacity(0.18)
        /// The soft cyan glow of decorative states.
        public static let glowCyan = accentSecondary.opacity(0.10)

        // MARK: Legacy aliases

        /// Legacy name of the primary accent, kept for compatibility.
        public static let accentPurple = accent
        /// Legacy name of the secondary accent, kept for compatibility.
        public static let accentCyan = accentSecondary

        /// Resolves an adaptive semantic color from the given hex RGB values
        /// through a dynamic color provider, so the token follows the system
        /// color scheme without any view reading the scheme.
        private static func adaptive(light: UInt, dark: UInt) -> Color {
            #if canImport(UIKit)
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? Self.uiColor(hex: dark)
                    : Self.uiColor(hex: light)
            })
            #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return Self.nsColor(hex: isDark ? dark : light)
            })
            #else
            return Color(hex: dark)
            #endif
        }

        #if canImport(UIKit)
        /// A `UIColor` from the given hex RGB value.
        private static func uiColor(hex: UInt) -> UIColor {
            UIColor(red: Self.red(hex), green: Self.green(hex), blue: Self.blue(hex), alpha: 1)
        }
        #endif

        #if canImport(AppKit)
        /// An sRGB `NSColor` from the given hex RGB value.
        private static func nsColor(hex: UInt) -> NSColor {
            NSColor(srgbRed: Self.red(hex), green: Self.green(hex), blue: Self.blue(hex), alpha: 1)
        }
        #endif

        /// The red component of a hex RGB value in `[0, 1]`.
        private static func red(_ hex: UInt) -> CGFloat {
            CGFloat((hex >> 16) & 0xFF) / 255.0
        }

        /// The green component of a hex RGB value in `[0, 1]`.
        private static func green(_ hex: UInt) -> CGFloat {
            CGFloat((hex >> 8) & 0xFF) / 255.0
        }

        /// The blue component of a hex RGB value in `[0, 1]`.
        private static func blue(_ hex: UInt) -> CGFloat {
            CGFloat(hex & 0xFF) / 255.0
        }
    }

    /// The corner-radius scale (new_design.md §4).
    public enum Radii {
        /// Small — 8 pt.
        public static let small: CGFloat = 8
        /// Medium — 12 pt.
        public static let medium: CGFloat = 12
        /// Large — 16 pt.
        public static let large: CGFloat = 16
        /// Extra large — 20 pt.
        public static let xl: CGFloat = 20
        /// Cards — 18 pt.
        public static let card: CGFloat = 18
        /// Message bubbles — 20 pt.
        public static let bubble: CGFloat = 20
        /// The composer — 24 pt.
        public static let composer: CGFloat = 24
        /// Buttons — 14 pt.
        public static let button: CGFloat = 14
    }

    /// The spacing scale (new_design.md §18): 4, 8, 12, 16, 20, 24, 32, 40.
    public enum Spacing {
        /// 4 pt.
        public static let xs: CGFloat = 4
        /// 8 pt.
        public static let sm: CGFloat = 8
        /// 12 pt.
        public static let md: CGFloat = 12
        /// 16 pt.
        public static let lg: CGFloat = 16
        /// 20 pt.
        public static let xl: CGFloat = 20
        /// 24 pt.
        public static let xxl: CGFloat = 24
        /// 32 pt.
        public static let xxxl: CGFloat = 32
        /// 40 pt.
        public static let huge: CGFloat = 40
    }

    /// The typography scale — the native Dynamic Type text styles, so text
    /// scales with the user's accessibility size (new_design.md §3).
    public enum Typography {
        /// Large title — 28–32 pt bold.
        public static let largeTitle = Font.largeTitle.weight(.bold)
        /// Screen title — 22–24 pt semibold.
        public static let screenTitle = Font.title2.weight(.semibold)
        /// Section title — 16–18 pt semibold.
        public static let sectionTitle = Font.headline.weight(.semibold)
        /// Body — 15–16 pt regular.
        public static let body = Font.body
        /// Secondary — 13–14 pt.
        public static let secondary = Font.subheadline
        /// Caption — 11–12 pt.
        public static let caption = Font.caption
        /// Caption secondary.
        public static let caption2 = Font.caption2
    }

    /// The shadow colors of the design system — always soft, never heavy
    /// (new_design.md §1).
    public enum Shadows {
        /// The shadow of cards and elevated surfaces.
        public static let card = Color.black.opacity(0.18)
        /// The shadow of message bubbles.
        public static let bubble = Color.black.opacity(0.12)
        /// The shadow of the composer.
        public static let composer = Color.black.opacity(0.22)
    }

    /// The motion of the design system — spring-based, never mechanical
    /// (new_design.md §1).
    public enum Motion {
        /// The drawer slide-in spring.
        public static let drawer = Animation.spring(response: 0.32, dampingFraction: 0.82)
        /// The dim-backdrop fade.
        public static let fade = Animation.easeOut(duration: 0.2)
        /// The standard content animation.
        public static let standard = Animation.easeOut(duration: 0.2)
    }

    /// The maximum width of a message bubble, so long content never spans the
    /// full width of a large display (new_design.md §5).
    public static let maxBubbleWidth: CGFloat = 560
}

/// A `Color` from the given hex RGB value.
public extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

#endif
