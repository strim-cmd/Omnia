#if canImport(SwiftUI)

import SwiftUI

/// A shared error banner view for presenting failure and warning messages across
/// presentation views (UX audit V2).
///
/// Consolidates identical banner markup across `ConversationListView`,
/// `SettingsView`, and `ConversationScreenView`.
struct ErrorBannerView: View {
    let message: String
    var systemImage: String = "exclamationmark.triangle"
    var backgroundColor: Color = .red

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .accessibilityLabel(Text(message))
    }
}

#endif
