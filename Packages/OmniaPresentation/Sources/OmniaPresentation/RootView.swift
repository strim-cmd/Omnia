#if canImport(SwiftUI)

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
    /// The ready-to-render conversation list state.
    @State private var listState: ConversationListState?
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
    @State private var selectedProvider: ProviderIdentity?
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
            state: rendering(conversationStates[identity] ?? ConversationScreenState(messages: [])),
            draft: draftBinding(for: identity),
            onSend: send,
            onCancel: cancel,
            onRegenerate: regenerate(at:),
            onRetry: retry,
            onCopy: copy(at:),
            onSelectProvider: { selectProvider($0.identity) },
            onOpenProviders: openProvidersFromConversation,
            onOpenMenu: presentMenu
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
            }
        )
    }

    @ViewBuilder
    private var settingsScreen: some View {
        if let settingsState {
            SettingsView(
                state: settingsState,
                isDarkMode: $isDarkMode,
                onOpenAbout: openAbout,
                onOpenMenu: presentMenu
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
        do {
            settingsState = try await surface.settings.load(configurationKeys: configurationKeys)
        } catch is CancellationError {
            return
        } catch let error as RepositoryError {
            settingsState = SettingsState(
                connections: settingsState?.connections ?? [],
                configuration: settingsState?.configuration ?? [],
                failure: .repository(error)
            )
        } catch {
            settingsState = SettingsState(
                connections: settingsState?.connections ?? [],
                configuration: settingsState?.configuration ?? [],
                failure: .repository(.storageUnavailable)
            )
        }
        await resolveProviderSelection()
        await resolveDarkModeAppearance()
    }

    /// Restores the persisted dark-mode choice through the settings surface and
    /// applies it to the shell's color scheme (DES-011 §3.5). When no choice
    /// was ever stored the shell presents its first-launch default — the dark
    /// identity (new_design.md §13). A failure to read the choice surfaces as
    /// the settings failure — presented as it is, never silent (ARC-001).
    @MainActor
    private func resolveDarkModeAppearance() async {
        do {
            isDarkMode = try await surface.settings.resolved(for: Self.darkModeKey) ?? true
        } catch is CancellationError {
            return
        } catch {
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
    private func resolveProviderSelection() async {
        do {
            selectedProvider = try await surface.settings.resolved(for: Self.providerSelectionKey)
        } catch is CancellationError {
            return
        } catch {
            settingsState = failingSettingsState(error)
        }
    }

    /// The ready-to-render provider selection of the presented conversation,
    /// composed from the provider connections and the error condition of the
    /// settings state the shell rendered, and the user's explicit selection;
    /// `nil` while the settings state has not loaded yet (UX audit V2, DES-012
    /// §3.2).
    private var providerSelection: ConversationScreenState.ProviderSelection? {
        guard let settingsState else { return nil }
        return .composed(
            providers: settingsState.connections,
            settingsFailure: settingsState.failure,
            selected: selectedProvider
        )
    }

    /// Attaches the current provider selection to the screen state, so the
    /// conversation screen presents the provider selector (UX audit V2). The
    /// shell composes the selection across the settings and conversation
    /// surfaces, which the surfaces themselves do not see (ARC-006).
    private func rendering(_ state: ConversationScreenState) -> ConversationScreenState {
        state.replacingProviderSelection(providerSelection)
    }

    // MARK: Conversation list intents

    /// Translates the create intent: a fresh conversation is created through
    /// the conversation list surface in the presented workspace — so it joins
    /// the membership-driven list (DES-012 §3.3, DES-011 §3.8) — its screen is
    /// presented, and the list reloads when the shell returns to it.
    private func createConversation() {
        Task { @MainActor in
            do {
                let conversation = try await surface.conversationList.create(in: workspace)
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

    /// Translates the select intent: the conversation is resolved through the
    /// conversation list surface and its screen is presented (DES-012 §3.3).
    private func openConversation(_ identity: ConversationIdentity) {
        guard case .conversationList = navigation.currentRoute else { return }
        Task { @MainActor in
            do {
                guard let conversation = try await surface.conversationList.select(identity) else { return }
                let loaded = surface.conversationScreen.load(conversation)
                let coordinated = await generationCoordinator.state(for: identity, loading: loaded)
                conversationStates[identity] = coordinated
                    .replacingDraft(conversationDrafts[identity] ?? "")
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
                try await surface.conversationList.delete(identity)
                conversationStates[identity] = nil
                conversationDrafts[identity] = nil
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
        let message = Message(role: .user, content: text)
        let request = SendMessageRequest(
            conversation: identity,
            message: message,
            userSelection: selectedProvider
        )
        let history = (conversationStates[identity]?.messages ?? [])
            + [MessagePresentation(message: message)]
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
            message: Message(role: .user, content: prompt.content?.accessibilityText ?? ""),
            userSelection: selectedProvider
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
                message: Message(role: .user, content: prompt.content?.accessibilityText ?? ""),
                userSelection: selectedProvider
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
    private func selectProvider(_ identity: ProviderIdentity?) {
        selectedProvider = identity
        Task { @MainActor in
            do {
                if let identity {
                    try await surface.settings.store(identity, for: Self.providerSelectionKey, at: .workspaceOverride)
                } else {
                    try await surface.settings.remove(Self.providerSelectionKey, at: .workspaceOverride)
                }
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
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: true,
            editing: nil
        )
    }

    /// Translates the cancel intent of the connection form.
    private func dismissConnectionForm() {
        guard let current = settingsState else { return }
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: false
        )
    }

    /// Translates the open-about intent of the settings surface: the shell
    /// routes to the about surface (DES-012 §3.5, SCREENS/SETTINGS.md).
    private func openAbout() {
        navigation = NavigationState(currentRoute: .about)
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
    /// reloads. An empty model records no model, so the provider falls back to
    /// the app-edge default (DES-011 §3.10).
    private func configure(_ request: ConfigureProviderRequest, endpoint: String, model: String) {
        Task { @MainActor in
            do {
                let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await surface.settings.configure(
                    request,
                    endpoint: endpoint,
                    model: trimmedModel.isEmpty ? nil : trimmedModel
                )
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
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
                let removedSelection = selectedProvider == identity
                if removedSelection {
                    selectedProvider = nil
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
        Task { @MainActor in
            do {
                let endpoint = try await surface.settings.endpoint(for: item.identity)
                let model = try await surface.settings.model(for: item.identity)
                guard let current = settingsState else { return }
                settingsState = SettingsState(
                    connections: current.connections,
                    configuration: current.configuration,
                    isComposing: false,
                    editing: SettingsState.Editing(
                        identity: item.identity,
                        displayName: item.displayName,
                        capabilities: item.capabilities,
                        limits: item.limits,
                        version: item.version,
                        currentEndpoint: endpoint ?? "",
                        currentModel: model ?? ""
                    )
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
    /// model, so the provider falls back to the app-edge default (DES-011
    /// §3.10).
    private func updateProvider(
        _ identity: ProviderIdentity,
        _ request: ProviderUpdateRequest,
        _ endpoint: String,
        _ model: String
    ) {
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
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: false,
            editing: nil
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
        default: .repository(.storageUnavailable)
        }
        return SettingsState(
            connections: settingsState?.connections ?? [],
            configuration: settingsState?.configuration ?? [],
            isComposing: settingsState?.isComposing ?? false,
            editing: settingsState?.editing,
            failure: failure
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
