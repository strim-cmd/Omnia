import Foundation

/// The fixed geometry and settling rules for the conversation row's single
/// trailing delete action. It is intentionally scoped to this row rather than
/// forming a general-purpose swipe framework.
enum ConversationSwipeBehavior {
    static let actionDiameter: CGFloat = 54
    static let trailingMargin: CGFloat = 14
    static let cardActionGap: CGFloat = 10
    static let revealDistance = actionDiameter + trailingMargin + cardActionGap
    static let settleThreshold = revealDistance / 2
    static let resistance: CGFloat = 0.2

    static func horizontalTranslation(width: CGFloat, height: CGFloat) -> CGFloat? {
        guard abs(width) > abs(height) else { return nil }
        return width
    }

    static func offset(isOpen: Bool, dragTranslation: CGFloat) -> CGFloat {
        let restingOffset = isOpen ? -revealDistance : 0
        let proposedOffset = restingOffset + dragTranslation

        if proposedOffset > 0 {
            return proposedOffset * resistance
        }
        if proposedOffset < -revealDistance {
            return -revealDistance
                + (proposedOffset + revealDistance) * resistance
        }
        return proposedOffset
    }

    static func settlesOpen(wasOpen: Bool, dragTranslation: CGFloat) -> Bool {
        if wasOpen {
            return dragTranslation < settleThreshold
        }
        return dragTranslation <= -settleThreshold
    }
}
