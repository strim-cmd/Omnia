import Foundation

/// The proportional width cap shared by user, assistant, streaming, and
/// interrupted message rows. The policy is independent of any device width;
/// SwiftUI supplies the current readable container width at layout time.
enum MessageBubbleWidthPolicy {
    static let maximumWidthRatio: CGFloat = 0.8

    static func maximumWidth(for availableWidth: CGFloat) -> CGFloat {
        max(0, availableWidth) * maximumWidthRatio
    }

    static func resolvedWidth(measuredWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        min(max(0, measuredWidth), maximumWidth(for: availableWidth))
    }
}
