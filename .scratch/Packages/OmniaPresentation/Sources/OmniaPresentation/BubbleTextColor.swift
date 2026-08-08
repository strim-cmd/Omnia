import Foundation

/// The text color of a message bubble, chosen for WCAG AA contrast against
/// the bubble background (DES-012 §3.1, Conversation module, UX audit V1).
///
/// The conversation screen renders the user bubble with `Color.accentColor`,
/// a semantic color the user can customize, so a fixed white label cannot
/// guarantee AA contrast with light or custom accents. This rule picks the
/// higher-contrast candidate of white and black for the background's sRGB
/// components; the default system accent in both light and dark mode chooses
/// black text and meets WCAG AA (≥ 4.5:1), verified by the Linux test
/// environment (DES-012 §3.7).
///
/// The value type is immutable, equal by value, `Equatable` and `Sendable`,
/// and owns no business logic (ARC-002, ARC-003).
public enum BubbleTextColor: Equatable, Sendable {
    /// White text.
    case white
    /// Black text.
    case black

    /// The bubble text color that meets WCAG AA contrast against a background
    /// with the given sRGB components in [0, 1]: the higher-contrast candidate
    /// of white and black (UX audit V1).
    public static func contrasting(
        backgroundRed red: Double,
        green: Double,
        blue: Double
    ) -> BubbleTextColor {
        let luminance = relativeLuminance(red: red, green: green, blue: blue)
        let whiteRatio = contrastRatio(1.0, luminance)
        let blackRatio = contrastRatio(0.0, luminance)
        return whiteRatio >= blackRatio ? .white : .black
    }

    /// The WCAG relative luminance of an sRGB color in [0, 1], computed from
    /// its components in [0, 1] (WCAG 2.x).
    public static func relativeLuminance(
        red: Double,
        green: Double,
        blue: Double
    ) -> Double {
        0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    /// The WCAG contrast ratio of two relative luminances in [1, 21] (WCAG
    /// 2.x).
    public static func contrastRatio(_ first: Double, _ second: Double) -> Double {
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The WCAG linearization of an sRGB component in [0, 1].
    private static func linearized(_ component: Double) -> Double {
        let clamped = min(max(component, 0), 1)
        if clamped <= 0.04045 {
            return clamped / 12.92
        }
        return pow((clamped + 0.055) / 1.055, 2.4)
    }
}
