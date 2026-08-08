#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

/// The SwiftUI rendering of the conversation list (DES-012 §3.3): the
/// conversation rows — display title and preview — and the create, select, and
/// delete intents, translated to callbacks for the application edge to deliver
/// to `ConversationListSurface`. The view renders state and translates intent;
/// it owns no business logic (ARC-002). Deleting a conversation is the user's
/// removal of their own content (ARC-005).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `.ai/standards/UI.md`.
@available(iOS 15.0, macOS 12.0, *)
public struct ConversationListView: View {
    /// The ready-to-render list state.
    public let state: ConversationListState
    /// Translates the create intent.
    public let onCreate: () -> Void
    /// Translates the select intent for the conversation with the given
    /// identity.
    public let onSelect: (ConversationIdentity) -> Void
    /// Translates the delete intent for the conversation with the given
    /// identity.
    public let onDelete: (ConversationIdentity) -> Void

    /// The conversation awaiting destructive confirmation before the delete
    /// intent is translated — nil until a destructive action is requested.
    /// A full swipe never deletes: the confirm step is explicit and the
    /// system confirmation dialog is the accessibility path (UX audit U5).
    @State private var pendingDeletion: ConversationIdentity?

    /// Creates a conversation list view over the given state and intent
    /// callbacks.
    public init(
        state: ConversationListState,
        onCreate: @escaping () -> Void,
        onSelect: @escaping (ConversationIdentity) -> Void,
        onDelete: @escaping (ConversationIdentity) -> Void
    ) {
        self.state = state
        self.onCreate = onCreate
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        List {
            ForEach(state.items, id: \.identity) { item in
                row(item)
            }
        }
        .navigationTitle(Localized.conversation)
        .overlay {
            if state.isEmpty {
                emptyState
            }
        }
        .safeAreaInset(edge: .top) {
            if let failure = state.failure {
                failureBanner(failure)
            }
        }
        .confirmationDialog(
            Localized.deleteConversation,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { presented in
                    if !presented {
                        pendingDeletion = nil
                    }
                }
            ),
            presenting: pendingDeletion
        ) { identity in
            Button(Localized.delete, role: .destructive) {
                onDelete(identity)
            }
        } message: { _ in
            Text(Localized.deleteConversationConfirmation)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreate) {
                    Label(Localized.newConversation, systemImage: "square.and.pencil")
                }
                .accessibilityLabel(Text(Localized.newConversation))
            }
        }
    }

    private func row(_ item: ConversationListItem) -> some View {
        Button {
            onSelect(item.identity)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if item.displayTitle.isEmpty {
                    Text(Localized.untitledConversation)
                        .font(.headline)
                } else {
                    Text(item.displayTitle)
                        .font(.headline)
                }
                if let preview = item.displayPreview {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(role: .destructive) {
                pendingDeletion = item.identity
            } label: {
                Label(Localized.delete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = item.identity
            } label: {
                Label(Localized.delete, systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            title: Localized.noConversations,
            description: Localized.noConversationsDescription,
            systemImage: "bubble.left.and.bubble.right"
        )
    }

    private func failureBanner(_ failure: RepositoryError) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
    }
}

#endif
