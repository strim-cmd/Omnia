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
    /// Translates an explicit user rename.
    public let onRename: (ConversationIdentity, String) -> Void
    /// Whether first-launch provider setup is the useful empty-state action.
    public let showsProviderSetup: Bool
    public let onAddProvider: () -> Void
    /// Translates the open-menu intent: the navigation drawer is presented.
    public let onOpenMenu: () -> Void

    /// The conversation awaiting destructive confirmation before the delete
    /// intent is translated — nil until a destructive action is requested.
    /// A full swipe never deletes: the confirm step is explicit and the
    /// system confirmation dialog is the accessibility path (UX audit U5).
    @State private var pendingDeletion: ConversationIdentity?
    /// The conversation currently presented in the rename sheet and its
    /// editable title. The existing value is retained if saving fails.
    @State private var pendingRename: ConversationIdentity?
    @State private var renameDraft = ""
    /// The one conversation whose card is settled left to expose the circular
    /// delete affordance. Opening or tapping elsewhere closes the prior row.
    @State private var revealedConversation: ConversationIdentity?
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
        onRename: @escaping (ConversationIdentity, String) -> Void = { _, _ in },
        showsProviderSetup: Bool = false,
        onAddProvider: @escaping () -> Void = {},
        onOpenMenu: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onCreate = onCreate
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onRename = onRename
        self.showsProviderSetup = showsProviderSetup
        self.onAddProvider = onAddProvider
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
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #else
        .toolbar(.hidden, for: .navigationBar)
        #endif
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
        .sheet(
            isPresented: Binding(
                get: { pendingRename != nil },
                set: { presented in
                    if !presented { pendingRename = nil }
                }
            )
        ) {
            renameSheet
        }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: OmniaTheme.Spacing.lg) {
            Text(Localized.renameConversation)
                .font(OmniaTheme.Typography.screenTitle)
            TextField(Localized.conversationTitle, text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(Text(Localized.conversationTitle))
            HStack {
                OmniaButton(title: Localized.cancel, style: .secondary) {
                    pendingRename = nil
                }
                Spacer()
                OmniaButton(title: Localized.save, systemImage: "checkmark") {
                    guard let identity = pendingRename else { return }
                    onRename(identity, renameDraft)
                    pendingRename = nil
                }
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(OmniaTheme.Spacing.xl)
        .frame(minWidth: 300)
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

    /// A local-calendar group header. Search results keep their activity group
    /// instead of being flattened into a misleading Today section.
    private func groupHeader(_ group: ConversationDateGroup) -> some View {
        Text(groupTitle(group))
            .font(OmniaTheme.Typography.caption)
            .foregroundStyle(OmniaTheme.Colors.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(.uppercase)
    }

    private func groupTitle(_ group: ConversationDateGroup) -> String {
        switch group {
        case .future: return Localized.future
        case .today: return Localized.today
        case .yesterday: return Localized.yesterday
        case .previousSevenDays: return Localized.previousSevenDays
        case .older: return Localized.older
        }
    }

    /// Conversation cards inside full-width List rows. The card itself moves
    /// over the normal list background to expose one independent circular
    /// destructive action; no full-height swipe-action slab is rendered.
    private var list: some View {
        List {
            if state.isEmpty {
                EmptyView()
            } else if hasQuery && filteredItems.isEmpty {
                noResultsRow
            } else {
                ForEach(filteredSections, id: \.group) { section in
                    groupHeader(section.group)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(
                                top: OmniaTheme.Spacing.sm,
                                leading: OmniaTheme.Spacing.lg,
                                bottom: OmniaTheme.Spacing.xs,
                                trailing: OmniaTheme.Spacing.lg
                            )
                        )
                    ForEach(section.items, id: \.identity) { item in
                        ConversationSwipeRevealRow(
                            identity: item.identity,
                            revealedConversation: $revealedConversation,
                            onDelete: {
                                revealedConversation = nil
                                pendingDeletion = item.identity
                            }
                        ) {
                            row(item)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(
                                top: OmniaTheme.Spacing.xs,
                                leading: 0,
                                bottom: OmniaTheme.Spacing.xs,
                                trailing: 0
                            )
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .simultaneousGesture(
            TapGesture().onEnded {
                closeRevealedConversation()
            }
        )
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

    private var filteredSections: [ConversationListSection] {
        ConversationListState(items: filteredItems).sections()
    }

    private func row(_ item: ConversationListItem) -> some View {
        Button {
            if revealedConversation == nil {
                onSelect(item.identity)
            } else {
                closeRevealedConversation()
            }
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
        .accessibilityAction(named: Text(Localized.rename)) {
            beginRename(item)
        }
        .accessibilityAction(named: Text(Localized.delete)) {
            revealedConversation = nil
            pendingDeletion = item.identity
        }
        .contextMenu {
            Button {
                beginRename(item)
            } label: {
                Label(Localized.rename, systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletion = item.identity
            } label: {
                Label(Localized.delete, systemImage: "trash")
            }
        }
    }

    private func beginRename(_ item: ConversationListItem) {
        revealedConversation = nil
        renameDraft = item.displayTitle
        pendingRename = item.identity
    }

    private func closeRevealedConversation() {
        guard revealedConversation != nil else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            revealedConversation = nil
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
        Group {
            if showsProviderSetup {
                EmptyStateView(
                    title: Localized.addFirstProvider,
                    description: Localized.addFirstProviderDescription,
                    systemImage: "externaldrive.connected.to.line.below",
                    actionTitle: Localized.addProvider,
                    action: onAddProvider
                )
            } else {
                EmptyStateView(
                    title: Localized.startNewConversation,
                    description: Localized.startNewConversationDescription,
                    systemImage: "bubble.left.and.bubble.right"
                )
            }
        }
    }

    private func failureBanner(_ failure: RepositoryError) -> some View {
        ErrorBannerView(message: FailureCopy.message(for: failure))
            .padding(.horizontal, OmniaTheme.Spacing.lg)
            .padding(.bottom, OmniaTheme.Spacing.sm)
    }

    /// User-facing copy for the typed failure the list presents — view-layer
    /// text derived from the typed error, never raw error detail (ARC-005). The
    /// failure is presented as it is, never silent (ARC-001): the banner text
    /// and its accessibility label both carry the message (UX audit A2/S2).
    enum FailureCopy {
        static func message(for failure: RepositoryError) -> String {
            switch failure {
            case .storageUnavailable:
                return Localized.storageUnavailable
            }
        }
    }
}

/// A single-purpose swipe container for a conversation card. Only a
/// horizontal-dominant drag contributes offset, so the enclosing List keeps
/// ownership of ordinary vertical scrolling.
private struct ConversationSwipeRevealRow<Content: View>: View {
    let identity: ConversationIdentity
    @Binding var revealedConversation: ConversationIdentity?
    let onDelete: () -> Void
    let content: Content

    @GestureState private var dragTranslation: CGFloat = 0

    init(
        identity: ConversationIdentity,
        revealedConversation: Binding<ConversationIdentity?>,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.identity = identity
        self._revealedConversation = revealedConversation
        self.onDelete = onDelete
        self.content = content()
    }

    private var isOpen: Bool {
        revealedConversation == identity
    }

    private var offset: CGFloat {
        ConversationSwipeBehavior.offset(
            isOpen: isOpen,
            dragTranslation: dragTranslation
        )
    }

    private var revealProgress: CGFloat {
        min(1, max(0, -offset / ConversationSwipeBehavior.revealDistance))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OmniaTheme.Colors.userBubbleText)
                    .frame(
                        width: ConversationSwipeBehavior.actionDiameter,
                        height: ConversationSwipeBehavior.actionDiameter
                    )
                    .background(OmniaTheme.Colors.error, in: Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .padding(.trailing, ConversationSwipeBehavior.trailingMargin)
            .opacity(revealProgress)
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
            .accessibilityLabel(Text(Localized.delete))

            content
                .offset(x: offset)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(horizontalDrag)
    }

    private var horizontalDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragTranslation) { value, translation, _ in
                guard let horizontal = ConversationSwipeBehavior.horizontalTranslation(
                    width: value.translation.width,
                    height: value.translation.height
                ) else { return }
                translation = horizontal
            }
            .onChanged { value in
                guard ConversationSwipeBehavior.horizontalTranslation(
                    width: value.translation.width,
                    height: value.translation.height
                ) != nil else { return }
                guard let revealedConversation, revealedConversation != identity else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    self.revealedConversation = nil
                }
            }
            .onEnded { value in
                guard let horizontal = ConversationSwipeBehavior.horizontalTranslation(
                    width: value.translation.width,
                    height: value.translation.height
                ) else { return }
                let shouldOpen = ConversationSwipeBehavior.settlesOpen(
                    wasOpen: isOpen,
                    dragTranslation: horizontal
                )
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    revealedConversation = shouldOpen ? identity : nil
                }
            }
    }
}

#endif
