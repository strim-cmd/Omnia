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
/// The list is the product's home (new_design.md §6): a light custom top bar
/// (menu, title, new chat), a search capsule, and premium card rows over the
/// same design system as the rest of the interface. The rows are card surfaces
/// with hidden separators — not the default List appearance. A full swipe never
/// deletes: the confirm step is explicit and the system confirmation dialog is
/// the accessibility path (UX audit U5).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`.
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
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void

    /// The conversation awaiting destructive confirmation before the delete
    /// intent is translated — nil until a destructive action is requested.
    /// A full swipe never deletes: the confirm step is explicit and the
    /// system confirmation dialog is the accessibility path (UX audit U5).
    @State private var pendingDeletion: ConversationIdentity?
    /// The search query filtering the presented rows — purely presentational
    /// (new_design.md §6).
    @State private var query = ""

    /// Creates a conversation list view over the given state and intent
    /// callbacks.
    public init(
        state: ConversationListState,
        onCreate: @escaping () -> Void,
        onSelect: @escaping (ConversationIdentity) -> Void,
        onDelete: @escaping (ConversationIdentity) -> Void,
        onOpenMenu: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onCreate = onCreate
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onOpenMenu = onOpenMenu
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            if let failure = state.failure {
                failureBanner(failure)
            }
            list
        }
        .background(OmniaBackground())
        .toolbar(.hidden, for: .navigationBar)
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
    }

    /// The light custom top bar of the list: the menu button, the centered
    /// title, and the new-chat button (new_design.md §6).
    private var header: some View {
        HStack {
            OmniaIconButton(systemImage: "line.3.horizontal", size: 36, action: onOpenMenu)
                .accessibilityLabel(Text(Localized.menu))
            Spacer()
            Text(Localized.conversations)
                .font(OmniaTheme.Typography.screenTitle)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer()
            OmniaIconButton(systemImage: "square.and.pencil", size: 36, action: onCreate)
                .accessibilityLabel(Text(Localized.newConversation))
        }
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.vertical, OmniaTheme.Spacing.sm)
    }

    /// The search capsule of the list: a dark elevated rounded capsule filtering
    /// the presented rows by title and preview (new_design.md §6).
    private var searchField: some View {
        HStack(spacing: OmniaTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OmniaTheme.Colors.textMuted)
            TextField("", text: $query, prompt: Text(Localized.searchConversations))
                .font(OmniaTheme.Typography.secondary)
                .foregroundStyle(OmniaTheme.Colors.textPrimary)
                .tint(OmniaTheme.Colors.accent)
                .autocorrectionDisabled()
            if !query.isEmpty {
                OmniaIconButton(
                    systemImage: "xmark.circle.fill",
                    tint: OmniaTheme.Colors.textMuted,
                    size: 20,
                    action: { query = "" }
                )
                .accessibilityLabel(Text(Localized.clearSearch))
            }
        }
        .padding(.horizontal, OmniaTheme.Spacing.md)
        .padding(.vertical, OmniaTheme.Spacing.xs)
        .background(OmniaTheme.Colors.elevatedSurface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(OmniaTheme.Colors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, OmniaTheme.Spacing.lg)
        .padding(.bottom, OmniaTheme.Spacing.sm)
    }

    /// The conversation rows over a plain, separator-free List, so the swipe
    /// delete affordance of the list contract is preserved while the rows read
    /// as premium cards, not standard list rows (new_design.md §6).
    private var list: some View {
        List {
            if state.isEmpty {
                EmptyView()
            } else if hasQuery && filteredItems.isEmpty {
                noResultsRow
            } else {
                ForEach(filteredItems, id: \.identity) { item in
                    row(item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(
                                top: OmniaTheme.Spacing.xs,
                                leading: OmniaTheme.Spacing.lg,
                                bottom: OmniaTheme.Spacing.xs,
                                trailing: OmniaTheme.Spacing.lg
                            )
                        )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if state.isEmpty {
                emptyState
            }
        }
    }

    /// The rows the query matches, or all rows when the query is empty.
    private var filteredItems: [ConversationListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return state.items }
        return state.items.filter { item in
            item.displayTitle.localizedCaseInsensitiveContains(trimmed)
                || (item.displayPreview?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func row(_ item: ConversationListItem) -> some View {
        Button {
            onSelect(item.identity)
        } label: {
            OmniaCard {
                HStack(spacing: OmniaTheme.Spacing.md) {
                    conversationIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle.isEmpty ? Localized.untitledConversation : item.displayTitle)
                            .font(OmniaTheme.Typography.body.weight(.semibold))
                            .foregroundStyle(OmniaTheme.Colors.textPrimary)
                            .lineLimit(1)
                        if let preview = item.displayPreview {
                            Text(preview)
                                .font(OmniaTheme.Typography.secondary)
                                .foregroundStyle(OmniaTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: OmniaTheme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(OmniaTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(OmniaTheme.Colors.textMuted)
                }
            }
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

    /// The conversation glyph of a row: a thin bubble symbol in a soft accent
    /// tile (new_design.md §6, §15).
    private var conversationIcon: some View {
        Image(systemName: "bubble.left")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(OmniaTheme.Colors.accent)
            .frame(width: 36, height: 36)
            .background(
                OmniaTheme.Colors.accentSubtle,
                in: RoundedRectangle(cornerRadius: OmniaTheme.Radii.medium, style: .continuous)
            )
    }

    /// The search-no-results row.
    private var noResultsRow: some View {
        Text(Localized.noSearchResults)
            .font(OmniaTheme.Typography.secondary)
            .foregroundStyle(OmniaTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.top, OmniaTheme.Spacing.xxxl)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: Localized.startNewConversation,
            description: Localized.startNewConversationDescription,
            systemImage: "bubble.left.and.bubble.right"
        )
    }

    private func failureBanner(_ failure: RepositoryError) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
            .padding(.horizontal, OmniaTheme.Spacing.lg)
            .padding(.bottom, OmniaTheme.Spacing.sm)
    }
}

#endif
