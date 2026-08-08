#if canImport(SwiftUI)

import SwiftUI

/// A shared empty-state view for presenting empty conditions across presentation
/// views (UX audit V2).
///
/// Consolidates identical empty-state markup across `ConversationListView` and
/// `SettingsView`.
struct EmptyStateView: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#endif
