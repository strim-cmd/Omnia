#if canImport(SwiftUI)

import SwiftUI

/// The section title of the Omnia design system: a semibold headline with the
/// primary text tone, the header of every card-based section (new_design.md
/// §3, §16).
struct SectionHeader: View {
    /// The section title.
    let title: String

    /// Creates a section header with the given title.
    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(OmniaTheme.Typography.sectionTitle)
            .foregroundStyle(OmniaTheme.Colors.textPrimary)
            .textCase(nil)
    }
}

#endif
