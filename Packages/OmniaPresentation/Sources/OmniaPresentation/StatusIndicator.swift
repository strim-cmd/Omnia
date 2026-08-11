#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The lifecycle status of a provider connection: a colored dot and the generic
/// lifecycle label — the rendering of the Domain `ProviderState` through the
/// shared helper, never provider-specific (ARC-004, new_design.md §5, §7).
struct StatusIndicator: View {
    /// The lifecycle state to present.
    let state: ProviderState
    /// Whether the lifecycle label is shown alongside the dot.
    var showsLabel = true

    /// Creates a status indicator for the given lifecycle state.
    init(state: ProviderState, showsLabel: Bool = true) {
        self.state = state
        self.showsLabel = showsLabel
    }

    var body: some View {
        HStack(spacing: OmniaTheme.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            if showsLabel {
                Text(label)
                    .font(OmniaTheme.Typography.caption)
                    .foregroundStyle(OmniaTheme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }

    /// The generic lifecycle label of the provider state (ARC-004,
    /// new_design.md §5, §7).
    var label: String {
        switch state {
        case .registered: return Localized.registered
        case .validated: return Localized.validated
        case .initializing: return Localized.initializing
        case .ready: return Localized.ready
        case .unavailable: return Localized.unavailable
        case .disabled: return Localized.disabled
        case .removed: return Localized.removed
        }
    }

    /// The dot color of the lifecycle state: the design's status colors — green
    /// for ready, cyan for validated, amber while initializing or unavailable,
    /// red for removed, muted otherwise.
    private var color: Color {
        switch state {
        case .ready:
            return OmniaTheme.Colors.success
        case .validated:
            return OmniaTheme.Colors.accentSecondary
        case .registered, .disabled:
            return OmniaTheme.Colors.textMuted
        case .initializing, .unavailable:
            return OmniaTheme.Colors.warning
        case .removed:
            return OmniaTheme.Colors.error
        }
    }
}

#endif
