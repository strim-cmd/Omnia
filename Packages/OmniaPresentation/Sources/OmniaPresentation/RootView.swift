#if canImport(SwiftUI)

import Foundation
import OmniaApplication
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// The SwiftUI rendering of the navigation surface (DES-012 §3.5): the shell
/// that hosts and routes between the conversation, providers, settings, and
/// about surfaces — the conversation list is the root destination, selecting a
/// conversation opens the conversation screen, and the list reaches the
/// providers, settings, and about surfaces. The view renders state and
/// translates intent; it owns no business logic (ARC-002, ARC-007).
///
/// The shell is composed over the `NavigationSurface` seam: it hosts the
/// conversation list, conversation screen, settings, and about surfaces the
/// Composition Root delivered (DES-012 §3.6, ARC-006), and routes between them
/// with the platform-native Navigation container (ADR-0001). The current route
/// is the frozen `NavigationState` model — presentation state owned at the
/// application edge (ARC-007, DES-012 §3.2). The view layer isolates all
/// platform code; the platform-independent navigation model is `NavigationState`
/// and the seam is `NavigationSurface` (§3.7).
///
/// The view is Apple-platform code, isolated behind platform availability; it
/// is not exercised by the Linux test environment (§3.7) and is verified by
/// review against `project UI standards`. It requires NavigationStack (iOS 16,
/// macOS 13); the hosted screens are available from iOS 15 / macOS 12.
@available(iOS 16.0, macOS 13.0, *)
@MainActor
public struct RootView: View {
    /// The navigation surface the shell hosts.
    public let surface: NavigationSurface
    /// The workspace whose conversations the conversation list presents
    /// (session state owned at the application edge, DES-011 §3.2).
    public let workspace: WorkspaceIdentity
    /// The typed configuration keys the settings surface presents.
    public let configurationKeys: [ConfigurationKey<String>]

    /// The current route of the navigation structure (DES-012 §3.5).
    @State private var navigation = NavigationState(currentRoute: .conversationList)
    /// Whether the navigation drawer is presented over the shell (new_design.md
    /// §8): the drawer is a slide-in overlay opened by the conversation list's
    /// menu button and closed by its dim backdrop or a row selection.
    @State private var isMenuPresented = false
    /// Whether the shell presents the dark color scheme (new_design.md §8,
    /// COMPONENTS.md — ThemeToggle): presented as the drawer's Dark Mode toggle
    /// and applied as the shell's preferred color scheme. Dark is the product's
    /// main visual identity and the first-launch default (new_design.md §13);
    /// turning the toggle off presents the light scheme. The value is shell
    /// presentation state, restored at launch and recorded on change through the
    /// typed configuration store (DES-011 §3.5) — never a Domain or Application
    /// concept (ARC-002).
    @State private var isDarkMode = true
    /// A persisted appearance restore updates the binding without writing the
    /// same value back (especially after Clear Data).
    @State private var suppressNextAppearancePersistence = false
    @State private var isClearingData = false
    /// Latest pending durable draft write per conversation. Replacing a task
    /// cancels a not-yet-started stale write; destructive boundaries await the
    /// canceled task before removing data so it cannot be recreated afterward.
    @State private var draftPersistenceTasks: [ConversationIdentity: Task<Void, Never>] = [:]
    /// The ready-to-render conversation list state.
    @State private var listState: ConversationListState?
    /// Guards rapid repeated create intents until the first operation either
    /// opens its new conversation or fails.
    @State private var isCreatingConversation = false
    /// Ready-to-render conversation screen states keyed by conversation
    /// identity. Navigation chooses which entry is visible; asynchronous loads
    /// and generation updates can never overwrite a different conversation.
    @State private var conversationStates: [ConversationIdentity: ConversationScreenState] = [:]
    /// The in-progress composer drafts of the conversations, keyed by
    /// identity: the rendered draft lives in its keyed conversation state, and this
    /// store lets an unsent draft survive leaving and returning to a
    /// conversation (UX audit U4).
    @State private var conversationDrafts: [ConversationIdentity: String] = [:]
    /// The ready-to-render settings state.
    @State private var settingsState: SettingsState?
    /// The user's explicit provider selection for the presented conversation,
    /// restored from the persisted configuration and changed from the
    /// conversation screen's provider selector (UX audit V2).
    @State private var legacySelectedProvider: ProviderIdentity?
    /// Exact provider/model choices keyed by conversation identity. The
    /// persisted aggregate is authoritative; this map is its render cache.
    @State private var conversationModelSelections: [ConversationIdentity: ProviderModelSelection] = [:]
    /// Identifies the currently relevant provider connection test. Closing or
    /// replacing the form changes this token, so a late result from an older
    /// request cannot overwrite the new form's condition.
    @State private var connectionTestOperation = UUID()
    /// Identifies the newest settings/catalog load. Older refreshes may finish
    /// later after network awaits, but can no longer replace newer provider,
    /// default, or model state.
    @State private var settingsLoadOperation = UUID()
    /// The session-lived owner of conversation generation. Its operations and
    /// latest states are keyed by conversation identity, so view and route
    /// changes affect observation only and never cancel provider work.
    @State private var generationCoordinator = ConversationGenerationCoordinator()

    /// Creates the navigation shell over the given navigation surface,
    /// workspace, and configuration keys.
    public init(
        surface: NavigationSurface,
        workspace: WorkspaceIdentity,
        configurationKeys: [ConfigurationKey<String>] = []
    ) {
        self.surface = surface
        self.workspace = workspace
        self.configurationKeys = configurationKeys
    }

    /// The typed configuration key of the user's explicit provider selection,
    /// stored at the user-owned workspace level (DES-011 §3.5, ARC-005). The
    /// key is the shell's own configuration vocabulary, presented only through
    /// the provider selector — it is not among the `ConfigurationKey<String>`
    /// rows the settings surface presents.
    private static let providerSelectionKey = ConfigurationKey<ProviderIdentity>("provider.selection")

    /// The typed configuration key of the shell's dark-mode choice, stored at
    /// the user-owned workspace level (DES-011 §3.5). Like the provider
    /// selection key, it is the shell's own configuration vocabulary — a stored
    /// `true` means the dark scheme and a stored `false` means the light scheme,
    /// and it is not among the `ConfigurationKey<String>` rows the settings
    /// surface presents.
    private static let darkModeKey = ConfigurationKey<Bool>("appearance.darkMode")

    public var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                Group {
                    if let listState {
                        ConversationListView(
                            state: listState,
                            onCreate: createConversation,
                            onSelect: openConversation,
                            onDelete: deleteConversation,
                            onRename: renameConversation,
                            showsProviderSetup: settingsState?.requiresProviderSetup == true,
                            onAddProvider: beginProviderSetup,
                            onOpenMenu: presentMenu
                        )
                    } else {
                        loadingState
                    }
                }
                .navigationDestination(
                    isPresented: Binding(
                        get: { destination.wrappedValue != nil },
                        set: { isPresented in
                            if !isPresented {
                                destination.wrappedValue = nil
                            }
                        }
                    )
                ) {
                    Group {
                        switch destination.wrappedValue {
                        case .conversation(let identity):
                            conversationScreen(for: identity)
                        case .providers:
                            providersScreen
                        case .settings:
                            settingsScreen
                        case .about:
                            aboutScreen
                        case nil:
                            EmptyView()
                        }
                    }
                }
                .task {
                    await loadSettings()
                }
                .task(id: navigation.currentRoute) {
                    guard navigation.currentRoute == .conversationList else { return }
                    await loadConversationList()
                }
                .onChange(of: isDarkMode) { dark in
                    if suppressNextAppearancePersistence {
                        suppressNextAppearancePersistence = false
                        return
                    }
                    persistDarkModeAppearance(dark)
                }
            }
            .disabled(isMenuPresented)

            if isMenuPresented {
                drawer
            }
        }
        .animation(OmniaTheme.Motion.drawer, value: isMenuPresented)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    /// The presented navigation drawer: the dim backdrop that closes it and the
    /// slide-in panel over the shell (new_design.md §8).
    private var drawer: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    isMenuPresented = false
                }

            SideMenuView(
                workspaceName: Localized.workspace,
                providerCount: settingsState?.connections.count ?? 0,
                currentRoute: navigation.currentRoute,
                isDarkMode: $isDarkMode,
                onNewChat: newChatFromMenu,
                onOpenConversations: {
                    closeMenu(route: .conversationList)
                },
                onOpenProviders: {
                    closeMenu(route: .providers)
                },
                onOpenSettings: {
                    closeMenu(route: .settings)
                },
                onOpenAbout: {
                    closeMenu(route: .about)
                }
            )
            .transition(.move(edge: .leading))
        }
        .transition(.opacity)
    }

    /// Presents the navigation drawer.
    private func presentMenu() {
        isMenuPresented = true
    }

    /// Closes the navigation drawer and routes to the given destination
    /// (DES-012 §3.5).
    private func closeMenu(route: NavigationState.Route) {
        isMenuPresented = false
        navigation = NavigationState(currentRoute: route)
    }

    // MARK: Routes

    /// The pushed destination of the navigation structure, bridged to the
    /// frozen `NavigationState` current route: `nil` presents the conversation
    /// list, a value presents the destination. Popping sets the route back to
    /// the conversation list (DES-012 §3.5).
    private var destination: Binding<Destination?> {
        Binding(
            get: {
                switch navigation.currentRoute {
                case .conversationList:
                    return nil
                case .conversationScreen(let conversation):
                    return .conversation(conversation)
                case .providers:
                    return .providers
                case .settings:
                    return .settings
                case .about:
                    return .about
                }
            },
            set: { value in
                navigation = NavigationState(currentRoute: value?.route ?? .conversationList)
            }
        )
    }

    private func conversationScreen(for identity: ConversationIdentity) -> some View {
        ConversationScreenView(
            state: rendering(
                conversationStates[identity] ?? ConversationScreenState(messages: []),
                for: identity
            ),
            draft: draftBinding(for: identity),
            onSend: send,
            onCancel: cancel,
            onRegenerate: regenerate(at:),
            onRetry: retry,
            onCopy: copy(at:),
            onSelectModel: { selectModel($0, for: identity) },
            onOpenProviders: openProvidersFromConversation,
            onOpenMenu: presentMenu,
            onAddFiles: { addFiles($0, to: identity) },
            onStageAttachments: { stageAttachments($0, for: identity) },
            onRemoveAttachment: { removeAttachment($0, from: identity) },
            onAttachmentFailure: { reportAttachmentFailure($0, for: identity) },
            onDismissFailure: { dismissFailure(for: identity) }
        )
    }

    /// A binding to the rendered draft of the presented conversation's state:
    /// typing edits the keyed state's draft directly and records the in-progress
    /// draft per conversation, so an unsent draft is never lost when the
    /// conversation is left and reopened (UX audit U4).
    private func draftBinding(for identity: ConversationIdentity) -> Binding<String> {
        Binding(
            get: {
                conversationStates[identity]?.draft
                    ?? conversationDrafts[identity]
                    ?? ""
            },
            set: { draft in
                conversationDrafts[identity] = draft
                let state = conversationStates[identity]
                    ?? ConversationScreenState(messages: [])
                conversationStates[identity] = state.replacingDraft(draft)
                persistDraft(draft, for: identity)
            }
        )
    }

    private func persistDraft(_ draft: String, for identity: ConversationIdentity) {
        guard let drafts = surface.drafts else { return }
        draftPersistenceTasks[identity]?.cancel()
        draftPersistenceTasks[identity] = Task { @MainActor in
            do {
                await Task.yield()
                try Task.checkCancellation()
                try await drafts.save(draft, for: identity)
            } catch is CancellationError {
                return
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    @MainActor
    private func removePersistedDraft(for identity: ConversationIdentity) async throws {
        let task = draftPersistenceTasks.removeValue(forKey: identity)
        task?.cancel()
        await task?.value
        try await surface.drafts?.remove(for: identity)
    }

    @MainActor
    private func finishPendingDraftPersistence() async {
        let tasks = Array(draftPersistenceTasks.values)
        draftPersistenceTasks.removeAll()
        for task in tasks { task.cancel() }
        for task in tasks { await task.value }
    }

    @MainActor
    private func restoreDraft(for identity: ConversationIdentity) async -> String {
        if let cached = conversationDrafts[identity] { return cached }
        guard let drafts = surface.drafts else { return "" }
        do {
            let restored = try await drafts.draft(for: identity)
            conversationDrafts[identity] = restored
            return restored
        } catch {
            // One malformed draft never makes its conversation unreachable.
            settingsState = failingSettingsState(error)
            conversationDrafts[identity] = ""
            return ""
        }
    }

    @ViewBuilder
    private var settingsScreen: some View {
        if let settingsState {
            SettingsView(
                state: settingsState,
                isDarkMode: $isDarkMode,
                onOpenAbout: openAbout,
                onOpenMenu: presentMenu,
                onOpenProviders: openProvidersFromSettings,
                onClearData: clearData,
                onSetDefaultModel: setDefaultModel,
                onSetModelCapability: setModelCapability
            )
        } else {
            loadingState
        }
    }

    /// The providers surface: the provider-connection management destination of
    /// the shell (new_design.md §7), distinct from the application-settings
    /// destination — configure, edit, and remove provider connections over the
    /// settings state's compose and provider-edit conditions (DES-012 §3.4).
    @ViewBuilder
    private var providersScreen: some View {
        if let settingsState {
            ProvidersView(
                state: settingsState,
                onCompose: presentConnectionForm,
                onCancel: dismissConnectionForm,
                onConfigure: configure,
                onEditProvider: editProvider,
                onUpdateProvider: updateProvider,
                onTestConnection: testConnection,
                onCancelEdit: cancelProviderEdit,
                onRemove: remove,
                onOpenMenu: presentMenu
            )
        } else {
            loadingState
        }
    }

    /// The about surface: the Omnia branding over the workspace context of the
    /// shell (new_design.md §8).
    private var aboutScreen: some View {
        AboutView(workspaceName: Localized.workspace, onOpenMenu: presentMenu)
    }

    // MARK: Loading

    /// The loading state shown until the first load resolves: a centered
    /// progress indicator, distinct from the loaded-but-empty state, so no
    /// empty-state flash appears while the conversation list or the settings
    /// load (UX audit U6). The pattern matches the shells' launch loading state.
    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text(Localized.loading))
    }

    @MainActor
    private func loadConversationList() async {
        do {
            listState = try await surface.conversationList.load(in: workspace)
        } catch is CancellationError {
            return
        } catch let error as RepositoryError {
            listState = ConversationListState(items: listState?.items ?? [], failure: error)
        } catch {
            listState = ConversationListState(items: listState?.items ?? [], failure: .storageUnavailable)
        }
    }

    @MainActor
    private func loadSettings() async {
        let operation = UUID()
        settingsLoadOperation = operation
        do {
            let loading = try await surface.settings.loadModelCatalogsLoading(
                configurationKeys: configurationKeys
            )
            guard settingsLoadOperation == operation else { return }
            settingsState = loading
            let loaded = try await surface.settings.load(configurationKeys: configurationKeys)
            guard settingsLoadOperation == operation else { return }
            settingsState = loaded
        } catch is CancellationError {
            return
        } catch let error as RepositoryError {
            guard settingsLoadOperation == operation else { return }
            settingsState = SettingsState(
                connections: settingsState?.connections ?? [],
                configuration: settingsState?.configuration ?? [],
                modelCatalogs: settingsState?.modelCatalogs ?? [],
                defaultModelSelection: settingsState?.defaultModelSelection,
                failure: .repository(error)
            )
        } catch {
            guard settingsLoadOperation == operation else { return }
            settingsState = SettingsState(
                connections: settingsState?.connections ?? [],
                configuration: settingsState?.configuration ?? [],
                modelCatalogs: settingsState?.modelCatalogs ?? [],
                defaultModelSelection: settingsState?.defaultModelSelection,
                failure: .repository(.storageUnavailable)
            )
        }
        guard settingsLoadOperation == operation else { return }
        await resolveProviderSelection(for: operation)
        await resolveDarkModeAppearance(for: operation)
    }

    /// Restores the persisted dark-mode choice through the settings surface and
    /// applies it to the shell's color scheme (DES-011 §3.5). When no choice
    /// was ever stored the shell presents its first-launch default — the dark
    /// identity (new_design.md §13). A failure to read the choice surfaces as
    /// the settings failure — presented as it is, never silent (ARC-001).
    @MainActor
    private func resolveDarkModeAppearance(for operation: UUID) async {
        do {
            let resolved = try await surface.settings.resolved(for: Self.darkModeKey) ?? true
            guard settingsLoadOperation == operation else { return }
            if isDarkMode != resolved {
                suppressNextAppearancePersistence = true
                isDarkMode = resolved
            }
        } catch is CancellationError {
            return
        } catch {
            guard settingsLoadOperation == operation else { return }
            settingsState = failingSettingsState(error)
        }
    }

    /// Records the shell's dark-mode choice through the settings surface at the
    /// user-owned workspace level (DES-011 §3.5, ARC-005): a stored `true`
    /// presents the dark scheme and a stored `false` presents the light scheme,
    /// restored on the next launch. The write is driven by the shared binding —
    /// the drawer and the settings toggle alike. A failure surfaces as the
    /// settings failure — never silent (ARC-001).
    private func persistDarkModeAppearance(_ dark: Bool) {
        Task { @MainActor in
            do {
                try await surface.settings.store(dark, for: Self.darkModeKey, at: .workspaceOverride)
            } catch is CancellationError {
                return
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Resolves the persisted provider selection through the settings surface
    /// and restores it as the user's explicit selection (DES-011 §3.5, UX audit
    /// V2). A failure to read the selection surfaces as the settings failure —
    /// presented as it is, never silent (ARC-001).
    @MainActor
    private func resolveProviderSelection(for operation: UUID) async {
        do {
            let resolved = try await surface.settings.resolved(for: Self.providerSelectionKey)
            guard settingsLoadOperation == operation else { return }
            legacySelectedProvider = resolved
        } catch is CancellationError {
            return
        } catch {
            guard settingsLoadOperation == operation else { return }
            settingsState = failingSettingsState(error)
        }
    }

    /// The ready-to-render provider selection of the presented conversation,
    /// composed from the provider connections and the error condition of the
    /// settings state the shell rendered, and the user's explicit selection;
    /// `nil` while the settings state has not loaded yet (UX audit V2, DES-012
    /// §3.2).
    private func providerSelection(
        for identity: ConversationIdentity
    ) -> ConversationScreenState.ProviderSelection? {
        guard let settingsState else { return nil }
        return .composed(
            providers: settingsState.connections,
            modelCatalogs: settingsState.modelCatalogs,
            settingsFailure: settingsState.failure,
            selectedModel: conversationModelSelections[identity]
        )
    }

    private func dismissFailure(for identity: ConversationIdentity) {
        guard let current = conversationStates[identity] else { return }
        conversationStates[identity] = current.replacingFailure(nil)
    }

    /// Attaches the current provider selection to the screen state, so the
    /// conversation screen presents the provider selector (UX audit V2). The
    /// shell composes the selection across the settings and conversation
    /// surfaces, which the surfaces themselves do not see (ARC-006).
    private func rendering(
        _ state: ConversationScreenState,
        for identity: ConversationIdentity
    ) -> ConversationScreenState {
        state.replacingProviderSelection(providerSelection(for: identity))
    }

    /// Restores an exact saved selection, or migrates a pre-M1 conversation to
    /// a valid default/legacy/deterministic model and persists that decision.
    /// No unavailable saved selection is replaced silently.
    @MainActor
    private func prepareModelSelection(
        for conversation: Conversation
    ) async throws -> Conversation {
        if let selection = conversation.modelSelection {
            conversationModelSelections[conversation.identity] = selection
            return conversation
        }
        guard let selection = initialModelSelection() else {
            conversationModelSelections[conversation.identity] = nil
            return conversation
        }
        let updated = try await surface.conversationList.selectModel(
            selection,
            for: conversation.identity
        )
        conversationModelSelections[conversation.identity] = selection
        return updated
    }

    /// Deterministic migration/default order: valid global default, legacy
    /// provider choice, then the first ready provider's first offered model.
    private func initialModelSelection() -> ProviderModelSelection? {
        guard let settingsState else { return nil }
        if let saved = settingsState.defaultModelSelection {
            // An invalid persisted default is a correction state, not license
            // to silently route a new conversation to another provider/model.
            return modelSelectionIsAvailable(saved, in: settingsState)
                ? saved
                : nil
        }
        if let legacySelectedProvider,
           let migrated = firstModel(
               for: legacySelectedProvider,
               in: settingsState
           ) {
            return migrated
        }
        for provider in settingsState.connections
        where ConversationScreenState.ProviderSelection.isAvailable(provider.state) {
            if let selection = firstModel(for: provider.identity, in: settingsState) {
                return selection
            }
        }
        return nil
    }

    private func firstModel(
        for provider: ProviderIdentity,
        in state: SettingsState
    ) -> ProviderModelSelection? {
        guard state.connections.contains(where: {
            $0.identity == provider
                && ConversationScreenState.ProviderSelection.isAvailable($0.state)
        }) else {
            return nil
        }
        return state.modelCatalogs
            .first { $0.provider == provider }?
            .models.first?.selection
    }

    private func modelSelectionIsAvailable(
        _ selection: ProviderModelSelection,
        in state: SettingsState
    ) -> Bool {
        state.connections.contains {
            $0.identity == selection.provider
                && ConversationScreenState.ProviderSelection.isAvailable($0.state)
        } && state.modelCatalogs
            .first { $0.provider == selection.provider }?
            .models.contains { $0.selection == selection } == true
    }

    // MARK: Conversation list intents

    /// Translates the create intent: a fresh conversation is created through
    /// the conversation list surface in the presented workspace — so it joins
    /// the membership-driven list (DES-012 §3.3, DES-011 §3.8) — its screen is
    /// presented, and the list reloads when the shell returns to it.
    private func createConversation() {
        guard !isCreatingConversation else { return }
        isCreatingConversation = true
        Task { @MainActor in
            defer { isCreatingConversation = false }
            do {
                let created = try await surface.conversationList.create(in: workspace)
                let conversation = try await prepareModelSelection(for: created)
                let loaded = surface.conversationScreen.load(conversation)
                let coordinated = await generationCoordinator.state(
                    for: conversation.identity,
                    loading: loaded
                )
                conversationStates[conversation.identity] = coordinated
                    .replacingDraft(conversationDrafts[conversation.identity] ?? "")
                guard case .conversationList = navigation.currentRoute else { return }
                navigation = NavigationState(
                    currentRoute: .conversationScreen(conversation: conversation.identity)
                )
            } catch let error as RepositoryError {
                listState = ConversationListState(items: listState?.items ?? [], failure: error)
            } catch {
                listState = ConversationListState(items: listState?.items ?? [], failure: .storageUnavailable)
            }
        }
    }

    /// Persists an explicit title and reloads the activity-sorted list. A
    /// generation completing concurrently merges the newer user title before
    /// it saves its terminal snapshot.
    private func renameConversation(_ identity: ConversationIdentity, to title: String) {
        Task { @MainActor in
            do {
                _ = try await surface.conversationList.rename(identity, to: title)
                await loadConversationList()
            } catch let error as RepositoryError {
                listState = ConversationListState(items: listState?.items ?? [], failure: error)
            } catch {
                listState = ConversationListState(
                    items: listState?.items ?? [],
                    failure: .storageUnavailable
                )
            }
        }
    }

    /// Translates the select intent: the conversation is resolved through the
    /// conversation list surface and its screen is presented (DES-012 §3.3).
    private func openConversation(_ identity: ConversationIdentity) {
        guard case .conversationList = navigation.currentRoute else { return }
        Task { @MainActor in
            do {
                guard let stored = try await surface.conversationList.select(identity) else { return }
                let conversation = try await prepareModelSelection(for: stored)
                let draft = await restoreDraft(for: identity)
                let loaded = surface.conversationScreen.load(conversation)
                let coordinated = await generationCoordinator.state(for: identity, loading: loaded)
                conversationStates[identity] = coordinated
                    .replacingDraft(draft)
                guard case .conversationList = navigation.currentRoute else { return }
                navigation = NavigationState(
                    currentRoute: .conversationScreen(conversation: identity)
                )
            } catch let error as RepositoryError {
                listState = ConversationListState(items: listState?.items ?? [], failure: error)
            } catch {
                listState = ConversationListState(items: listState?.items ?? [], failure: .storageUnavailable)
            }
        }
    }

    /// Translates the delete intent — the user's removal of their own content
    /// (DES-012 §3.3, ARC-005) — and reloads the list.
    private func deleteConversation(_ identity: ConversationIdentity) {
        Task { @MainActor in
            do {
                await generationCoordinator.discard(identity)
                for attachment in conversationStates[identity]?.draftAttachments ?? [] {
                    try? await surface.conversationScreen.remove(attachment)
                }
                try await surface.conversationList.delete(identity)
                do {
                    try await removePersistedDraft(for: identity)
                } catch {
                    settingsState = failingSettingsState(error)
                }
                conversationStates[identity] = nil
                conversationDrafts[identity] = nil
                conversationModelSelections[identity] = nil
                await loadConversationList()
            } catch let error as RepositoryError {
                listState = ConversationListState(items: listState?.items ?? [], failure: error)
            } catch {
                listState = ConversationListState(items: listState?.items ?? [], failure: .storageUnavailable)
            }
        }
    }

    // MARK: Conversation screen intents

    /// Translates the send intent: the user's message is composed into the
    /// frozen `SendMessageRequest` and the streaming flow is driven through the
    /// conversation screen surface, rendering the Domain `StreamingUpdate`
    /// events incrementally (DES-012 §3.3, DES-011 §3.3). Cancellation is
    /// cooperative and distinct from failure (DES-008, ARC-001).
    private func send(_ text: String) {
        guard case .conversationScreen(let identity) = navigation.currentRoute else { return }
        let baseHistory = conversationStates[identity]?.messages ?? []
        let attachments = conversationStates[identity]?.draftAttachments ?? []
        let message = Message(
            role: .user,
            content: text,
            attachments: attachments
        )
        let request = SendMessageRequest(
            conversation: identity,
            message: message,
            modelSelection: conversationModelSelections[identity]
        )
        let history = baseHistory + [MessagePresentation(message: message)]
        let conversationScreen = surface.conversationScreen
        startGeneration(
            for: identity,
            initialState: ConversationScreenState(
                messages: history,
                draft: text,
                draftAttachments: attachments,
                streamingCondition: .thinking
            )
        ) { consume in
            try await conversationScreen.performSend(
                request,
                rendering: history,
                fallbackHistory: baseHistory,
                preservingDraft: text,
                draftAttachments: attachments,
                onAccepted: {
                    do {
                        try await removePersistedDraft(for: identity)
                    } catch {
                        await MainActor.run {
                            settingsState = failingSettingsState(error)
                        }
                    }
                    await MainActor.run {
                        conversationDrafts[identity] = ""
                        if let current = conversationStates[identity] {
                            conversationStates[identity] = current
                                .replacingDraft("")
                                .replacingDraftAttachments([])
                        }
                    }
                },
                onState: consume
            )
        }
    }

    private func addFiles(_ urls: [URL], to identity: ConversationIdentity) {
        Task { @MainActor in
            let current = conversationStates[identity] ?? ConversationScreenState(messages: [])
            do {
                let attachments = try await surface.conversationScreen.stageFiles(
                    urls,
                    existing: current.draftAttachments
                )
                conversationStates[identity] = current.replacingDraftAttachments(attachments)
                await validateAttachments(for: identity)
            } catch let error as AttachmentError {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: error
                )
            } catch {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: .storageUnavailable
                )
            }
        }
    }

    private func stageAttachments(
        _ candidates: [AttachmentImportCandidate],
        for identity: ConversationIdentity
    ) {
        Task { @MainActor in
            let current = conversationStates[identity] ?? ConversationScreenState(messages: [])
            do {
                let attachments = try await surface.conversationScreen.stage(
                    candidates,
                    existing: current.draftAttachments
                )
                conversationStates[identity] = current.replacingDraftAttachments(attachments)
                await validateAttachments(for: identity)
            } catch let error as AttachmentError {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: error
                )
            } catch {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: .storageUnavailable
                )
            }
        }
    }

    private func removeAttachment(
        _ attachment: MessageAttachment,
        from identity: ConversationIdentity
    ) {
        Task { @MainActor in
            let current = conversationStates[identity] ?? ConversationScreenState(messages: [])
            do {
                try await surface.conversationScreen.remove(attachment)
                let attachments = current.draftAttachments.filter {
                    $0.identity != attachment.identity
                }
                conversationStates[identity] = current.replacingDraftAttachments(attachments)
                await validateAttachments(for: identity)
            } catch let error as AttachmentError {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: error
                )
            } catch {
                conversationStates[identity] = current.replacingDraftAttachments(
                    current.draftAttachments,
                    issue: .storageUnavailable
                )
            }
        }
    }

    private func reportAttachmentFailure(
        _ error: AttachmentError,
        for identity: ConversationIdentity
    ) {
        let current = conversationStates[identity] ?? ConversationScreenState(messages: [])
        conversationStates[identity] = current.replacingDraftAttachments(
            current.draftAttachments,
            issue: error
        )
    }

    @MainActor
    private func validateAttachments(for identity: ConversationIdentity) async {
        guard let current = conversationStates[identity] else { return }
        guard !current.draftAttachments.isEmpty else {
            conversationStates[identity] = current.replacingDraftAttachments([])
            return
        }
        guard let selection = conversationModelSelections[identity] else {
            conversationStates[identity] = current.replacingDraftAttachments(
                current.draftAttachments
            )
            return
        }
        do {
            try await surface.conversationScreen.validate(
                current.draftAttachments,
                for: selection
            )
            conversationStates[identity] = current.replacingDraftAttachments(
                current.draftAttachments
            )
        } catch let error as AttachmentError {
            conversationStates[identity] = current.replacingDraftAttachments(
                current.draftAttachments,
                issue: error
            )
        } catch {
            conversationStates[identity] = current.replacingDraftAttachments(
                current.draftAttachments,
                issue: .storageUnavailable
            )
        }
    }

    /// Translates the cancel intent of an active stream: the stream is stopped,
    /// and the rendered state becomes the interrupted condition the Domain
    /// preserved — the partial content is rendered as incomplete, never
    /// discarded (ARC-001) — so the screen announces the interruption and the
    /// Stop affordance gives way to the composer (UX audit A4).
    private func cancel() {
        guard case .conversationScreen(let identity) = navigation.currentRoute else { return }
        Task { @MainActor in
            _ = await generationCoordinator.cancel(identity)
        }
    }

    /// Translates the regenerate intent of an assistant message at the given
    /// index: the exchange is re-issued from the last user prompt at or before
    /// the message, truncating the stale assistant reply, so the response is
    /// regenerated in place (UI_REDESIGN_FINAL_REVIEW — message actions). The
    /// rendered history is truncated to the triggering prompt, so the fresh
    /// reply replaces the stale one; no user message is appended beyond the
    /// prompt already in the history (UX audit U7).
    private func regenerate(at index: Int) {
        guard case .conversationScreen(let identity) = navigation.currentRoute,
              let messages = conversationStates[identity]?.messages,
              messages.indices.contains(index),
              let promptIndex = messages[...index].lastIndex(where: { $0.role == .user })
        else {
            return
        }
        let prompt = messages[promptIndex]
        let request = SendMessageRequest(
            conversation: identity,
            message: Message(
                role: .user,
                content: prompt.content?.accessibilityText ?? "",
                attachments: prompt.attachments
            ),
            modelSelection: conversationModelSelections[identity]
        )
        let history = Array(messages.prefix(promptIndex + 1))
        let conversationScreen = surface.conversationScreen
        startGeneration(
            for: identity,
            initialState: ConversationScreenState(
                messages: history,
                streamingCondition: .thinking
            )
        ) { consume in
            try await conversationScreen.performSend(
                request,
                rendering: history,
                onState: consume
            )
        }
    }

    /// Translates the retry intent: an interrupted response resumes its
    /// preserved partial content — the last prompt is already in the history,
    /// and the resume carries the partial content forward into the reply
    /// instead of regenerating it (UX audit U7) — and a failed request re-sends
    /// the last user message (UX audit V2).
    private func retry() {
        guard case .conversationScreen(let identity) = navigation.currentRoute,
              let state = conversationStates[identity]
        else {
            return
        }
        let messages = state.messages
        // An interrupted stream resumes through the surface: a resume does not
        // add a user message, and the preserved partial content continues in
        // the reply (ConversationScreenSurface.resume).
        if case .interrupted(let partialContent) = state.streamingCondition {
            let conversationScreen = surface.conversationScreen
            startGeneration(
                for: identity,
                initialState: ConversationScreenState(
                    messages: messages,
                    streamingCondition: .active(partialContent: partialContent)
                )
            ) { consume in
                try await conversationScreen.performResume(
                    identity,
                    from: partialContent,
                    rendering: messages,
                    onState: consume
                )
            }
            return
        }
        guard let lastUserIndex = messages.indices.last(where: { messages[$0].role == .user })
        else {
            return
        }
        // If there's an assistant message after the last user message, we regenerate.
        // Otherwise we just re-send the last user message with the history before it.
        if let lastAssistantIndex = messages.indices.last(where: { messages[$0].role == .assistant }),
           lastAssistantIndex > lastUserIndex {
            regenerate(at: lastAssistantIndex)
        } else {
            let prompt = messages[lastUserIndex]
            let request = SendMessageRequest(
                conversation: identity,
                message: Message(
                    role: .user,
                    content: prompt.content?.accessibilityText ?? "",
                    attachments: prompt.attachments
                ),
                modelSelection: conversationModelSelections[identity]
            )
            let history = Array(messages.prefix(lastUserIndex + 1))
            let conversationScreen = surface.conversationScreen
            startGeneration(
                for: identity,
                initialState: ConversationScreenState(
                    messages: history,
                    streamingCondition: .thinking
                )
            ) { consume in
                try await conversationScreen.performSend(
                    request,
                    rendering: history,
                    onState: consume
                )
            }
        }
    }

    /// Starts a conversation-keyed generation operation and observes it only
    /// while its conversation is the rendered route. The coordinator retains
    /// both the operation and its latest state across route changes.
    private func startGeneration(
        for identity: ConversationIdentity,
        initialState: ConversationScreenState,
        perform: @escaping ConversationGenerationCoordinator.GenerationOperation
    ) {
        Task { @MainActor in
            _ = await generationCoordinator.start(
                for: identity,
                initialState: initialState,
                perform: perform
            ) { conversation, state in
                presentGenerationState(state, for: conversation)
            }
        }
    }

    /// Applies a generation update only to its keyed conversation state.
    /// Off-screen updates remain available on return and cannot bleed into
    /// whichever conversation is currently displayed.
    private func presentGenerationState(
        _ state: ConversationScreenState,
        for identity: ConversationIdentity
    ) {
        conversationStates[identity] = state
            .replacingDraft(conversationDrafts[identity] ?? "")
    }

    /// Translates the copy intent of an assistant message at the given index:
    /// its plain text is copied to the platform pasteboard — the user's own
    /// content (ARC-005).
    private func copy(at index: Int) {
        guard case .conversationScreen(let identity) = navigation.currentRoute,
              let messages = conversationStates[identity]?.messages,
              messages.indices.contains(index),
              let text = messages[index].content?.accessibilityText
        else {
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// Translates the provider-selection intent of the conversation screen: the
    /// explicit selection is presented immediately and persisted at the
    /// user-owned workspace level (DES-011 §3.5, ARC-005); the automatic
    /// selection — `nil` — clears the stored selection. A failure to persist
    /// surfaces as the settings failure, as it is, never silent (ARC-001). The
    /// selection is carried into the next `SendMessageRequest` as the frozen
    /// `userSelection`, which the selection policy of DES-009 §3.2 honors when
    /// it is selectable.
    private func selectModel(
        _ selection: ProviderModelSelection,
        for conversation: ConversationIdentity
    ) {
        Task { @MainActor in
            do {
                _ = try await surface.conversationList.selectModel(
                    selection,
                    for: conversation
                )
                conversationModelSelections[conversation] = selection
                await validateAttachments(for: conversation)
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    // MARK: Settings intents

    /// Translates the compose intent: the connection-form condition of the
    /// settings state is presented (DES-012 §3.4).
    private func presentConnectionForm() {
        guard let current = settingsState else { return }
        connectionTestOperation = UUID()
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            modelCatalogs: current.modelCatalogs,
            defaultModelSelection: current.defaultModelSelection,
            isComposing: true,
            editing: nil,
            connectionTestCondition: .idle
        )
    }

    /// Translates the cancel intent of the connection form.
    private func dismissConnectionForm() {
        guard let current = settingsState else { return }
        connectionTestOperation = UUID()
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            modelCatalogs: current.modelCatalogs,
            defaultModelSelection: current.defaultModelSelection,
            isComposing: false,
            connectionTestCondition: .idle
        )
    }

    /// Translates the open-about intent of the settings surface: the shell
    /// routes to the about surface (DES-012 §3.5, SCREENS/SETTINGS.md).
    private func openAbout() {
        navigation = NavigationState(currentRoute: .about)
    }

    private func openProvidersFromSettings() {
        navigation = NavigationState(currentRoute: .providers)
    }

    /// Executes the confirmed destructive scope, then reloads a valid empty
    /// first-launch state in the retained workspace shell.
    private func clearData() {
        guard !isClearingData else { return }
        isClearingData = true
        Task { @MainActor in
            defer { isClearingData = false }
            do {
                await finishPendingDraftPersistence()
                await generationCoordinator.discardAll()
                try await surface.settings.clearData()
                conversationStates.removeAll()
                conversationDrafts.removeAll()
                conversationModelSelections.removeAll()
                legacySelectedProvider = nil
                navigation = NavigationState(currentRoute: .conversationList)
                settingsState = nil
                listState = nil
                await loadSettings()
                await loadConversationList()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the open-providers intent of the conversation screen's
    /// provider banners — the provider-management destination of the navigation
    /// structure, where a connection is added or its state corrected, reached
    /// through the shell's normal routing (DES-012 §3.5).
    private func openProvidersFromConversation() {
        navigation = NavigationState(currentRoute: .providers)
    }

    /// Translates the new-chat intent of the drawer: the shell returns to the
    /// conversation list and creates a fresh conversation — the same intent as
    /// the conversation list's New Chat button (new_design.md §8, DES-012 §3.3).
    private func newChatFromMenu() {
        closeMenu(route: .conversationList)
        createConversation()
    }

    /// Translates the configure intent: the composed request, the declared
    /// endpoint, and the declared model are handed to the settings surface —
    /// the entered secret enters only the frozen `ConfigureProviderRequest`,
    /// never any rendered state (ARC-001, ARC-005) — and the settings state
    /// reloads. An empty model records no model and remains unavailable until
    /// discovery or a later manual model declaration provides one.
    private func configure(_ request: ConfigureProviderRequest, endpoint: String, model: String) {
        connectionTestOperation = UUID()
        Task { @MainActor in
            do {
                let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasFirstProvider = settingsState?.requiresProviderSetup == true
                let connection = try await surface.settings.configure(
                    request,
                    endpoint: endpoint,
                    model: trimmedModel.isEmpty ? nil : trimmedModel
                )
                if wasFirstProvider, !trimmedModel.isEmpty {
                    do {
                        try await surface.settings.setDefaultModelSelection(
                            ProviderModelSelection(
                                provider: connection.identity,
                                model: ModelReference(name: trimmedModel)
                            )
                        )
                    } catch {
                        // The validated provider is already durable. Close the
                        // add form before surfacing a default-write failure so
                        // retry cannot create a duplicate connection.
                        await loadSettings()
                        navigation = NavigationState(currentRoute: .conversationList)
                        settingsState = failingSettingsState(error)
                        return
                    }
                }
                await loadSettings()
                if wasFirstProvider {
                    navigation = NavigationState(currentRoute: .conversationList)
                }
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// First-launch empty-state path: open provider management directly in the
    /// add form so the user never has to discover the drawer first.
    private func beginProviderSetup() {
        navigation = NavigationState(currentRoute: .providers)
        presentConnectionForm()
    }

    /// Runs the generic endpoint/credential/model validation path. Candidate
    /// credentials remain only in the request value and are never copied into
    /// render state; failure leaves the form and all its local fields intact.
    private func testConnection(_ request: ProviderConnectionTestRequest) {
        let operation = UUID()
        connectionTestOperation = operation
        setConnectionTestCondition(.testing)
        Task { @MainActor in
            do {
                let result = try await surface.settings.testConnection(request)
                guard connectionTestResultIsCurrent(operation) else { return }
                setConnectionTestCondition(.succeeded(models: result.models))
            } catch let error as ProviderConnectionTestError {
                guard connectionTestResultIsCurrent(operation) else { return }
                setConnectionTestCondition(.failed(error))
            } catch is CancellationError {
                guard connectionTestResultIsCurrent(operation) else { return }
                setConnectionTestCondition(.idle)
            } catch {
                guard connectionTestResultIsCurrent(operation) else { return }
                setConnectionTestCondition(.failed(.invalidResponse))
            }
        }
    }

    private func connectionTestResultIsCurrent(_ operation: UUID) -> Bool {
        guard connectionTestOperation == operation, let state = settingsState else {
            return false
        }
        return state.isComposing || state.editing != nil
    }

    private func setDefaultModel(_ selection: ProviderModelSelection) {
        Task { @MainActor in
            do {
                try await surface.settings.setDefaultModelSelection(selection)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    private func setModelCapability(
        _ selection: ProviderModelSelection,
        _ capability: Capability,
        _ support: ModelCapabilitySupport
    ) {
        Task { @MainActor in
            do {
                let current = settingsState?.modelCatalogs
                    .first { $0.provider == selection.provider }?
                    .models.first { $0.selection == selection }?
                    .capabilities ?? ModelCapabilityProfile()
                let updated = current.replacing(support, for: capability)
                let persisted: ModelCapabilityProfile? =
                    updated.supported.isEmpty && updated.unsupported.isEmpty
                        ? nil
                        : updated
                try await surface.settings.setModelCapabilityOverride(
                    persisted,
                    for: selection
                )
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    private func setConnectionTestCondition(
        _ condition: SettingsState.ConnectionTestCondition
    ) {
        guard let current = settingsState else { return }
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            modelCatalogs: current.modelCatalogs,
            defaultModelSelection: current.defaultModelSelection,
            isComposing: current.isComposing,
            editing: current.editing,
            failure: current.failure,
            connectionTestCondition: condition
        )
    }

    /// Translates the remove intent — the user's removal of their own content
    /// and its stored credential (ARC-005) — and reloads the settings state. A
    /// removed provider that was the explicit selection is deselected: the
    /// in-memory selection clears and the stored selection is removed at the
    /// user-owned workspace level, its failure surfaced as the settings failure
    /// (ARC-001, UX audit V2).
    private func remove(_ identity: ProviderIdentity) {
        Task { @MainActor in
            do {
                try await surface.settings.remove(identity)
                let removedSelection = legacySelectedProvider == identity
                if removedSelection {
                    legacySelectedProvider = nil
                    try await surface.settings.remove(Self.providerSelectionKey, at: .workspaceOverride)
                }
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the provider-edit intent: the connection's recorded endpoint
    /// and model are resolved through the settings surface and the
    /// provider-edit condition of the settings state is presented — the same
    /// connection form as compose, pre-filled with the connection's current
    /// declaration, endpoint, and model, so a provider connection offers a way
    /// to edit instead of only Remove (UX audit U7). The condition holds only
    /// the configured connection state and the recorded endpoint and model,
    /// never a credential (ARC-001, ARC-005).
    private func editProvider(_ item: ProviderConnectionListItem) {
        connectionTestOperation = UUID()
        Task { @MainActor in
            do {
                let endpoint = try await surface.settings.endpoint(for: item.identity)
                let model = try await surface.settings.model(for: item.identity)
                guard let current = settingsState else { return }
                settingsState = SettingsState(
                    connections: current.connections,
                    configuration: current.configuration,
                    modelCatalogs: current.modelCatalogs,
                    defaultModelSelection: current.defaultModelSelection,
                    isComposing: false,
                    editing: SettingsState.Editing(
                        identity: item.identity,
                        displayName: item.displayName,
                        capabilities: item.capabilities,
                        limits: item.limits,
                        version: item.version,
                        currentEndpoint: endpoint ?? "",
                        currentModel: model ?? ""
                    ),
                    connectionTestCondition: .idle
                )
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the provider-update intent: the edited declaration, the
    /// declared endpoint, and the optional model are recorded through the
    /// settings surface — validated at the service boundary before any write
    /// (DES-011 §3.1, §3.9, §3.10, ARC-009) — the lifecycle state is preserved
    /// by the service, and the settings state reloads, so the edit form closes
    /// and the connection row reflects the change. An empty model records no
    /// model and remains unavailable until discovery or a later manual model
    /// declaration provides one.
    private func updateProvider(
        _ identity: ProviderIdentity,
        _ request: ProviderUpdateRequest,
        _ endpoint: String,
        _ model: String
    ) {
        connectionTestOperation = UUID()
        Task { @MainActor in
            do {
                let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await surface.settings.update(
                    request,
                    for: identity,
                    endpoint: endpoint,
                    model: trimmedModel.isEmpty ? nil : trimmedModel
                )
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the cancel intent of the provider-edit form.
    private func cancelProviderEdit() {
        guard let current = settingsState else { return }
        connectionTestOperation = UUID()
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            modelCatalogs: current.modelCatalogs,
            defaultModelSelection: current.defaultModelSelection,
            isComposing: false,
            editing: nil,
            connectionTestCondition: .idle
        )
    }

    /// Composes the settings state presenting the typed failure of a settings
    /// operation, as it is, never wrapped (DES-011 §3.6, DES-009 §3.9). The
    /// compose condition is preserved: a failed configure keeps the
    /// connection form presented with its input retained, so the failure is
    /// shown inside the form and no declaration is lost (UX audit U3). The
    /// provider-edit condition is preserved: a failed provider update keeps
    /// the edit form presented with its input retained.
    private func failingSettingsState(_ error: any Error) -> SettingsState {
        let failure: SettingsState.Failure = switch error {
        case let error as ApplicationValidationError: .application(error)
        case let error as RepositoryError: .repository(error)
        case let error as CredentialStorageError: .credentialStorage(error)
        case let error as CapabilityError: .capability(error)
        default: .repository(.storageUnavailable)
        }
        return SettingsState(
            connections: settingsState?.connections ?? [],
            configuration: settingsState?.configuration ?? [],
            modelCatalogs: settingsState?.modelCatalogs ?? [],
            defaultModelSelection: settingsState?.defaultModelSelection,
            isComposing: settingsState?.isComposing ?? false,
            editing: settingsState?.editing,
            failure: failure,
            connectionTestCondition: settingsState?.connectionTestCondition ?? .idle
        )
    }
}

/// A pushed destination of the navigation structure, bridged to the frozen
/// `NavigationState.Route`: the navigation container requires its destination
/// values to be `Hashable`, and the route model composes through `NavigationState`
/// (DES-012 §3.5). This type is view-layer plumbing, not part of the public
/// surface.
private enum Destination: Hashable {
    case conversation(ConversationIdentity)
    case providers
    case settings
    case about

    /// The frozen route this destination presents.
    var route: NavigationState.Route {
        switch self {
        case .conversation(let conversation):
            return .conversationScreen(conversation: conversation)
        case .providers:
            return .providers
        case .settings:
            return .settings
        case .about:
            return .about
        }
    }
}

#endif
