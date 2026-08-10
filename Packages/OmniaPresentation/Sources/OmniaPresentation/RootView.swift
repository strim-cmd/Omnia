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
/// that hosts and routes between the conversation and settings surfaces — the
/// conversation list is the root destination, selecting a conversation opens
/// the conversation screen, and the list reaches the settings surface. The
/// view renders state and translates intent; it owns no business logic
/// (ARC-002, ARC-007).
///
/// The shell is composed over the `NavigationSurface` seam: it hosts the
/// conversation list, conversation screen, and settings surfaces the
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
    /// §7): the drawer is a slide-in overlay opened by the conversation list's
    /// menu button and closed by its dim backdrop or a row selection.
    @State private var isMenuPresented = false
    /// The ready-to-render conversation list state.
    @State private var listState: ConversationListState?
    /// The conversation the conversation screen presents.
    @State private var presentedConversation: Conversation?
    /// The ready-to-render conversation screen state.
    @State private var screenState: ConversationScreenState?
    /// The in-progress composer drafts of the conversations, keyed by
    /// identity: the rendered draft lives in `screenState.draft`, and this
    /// store lets an unsent draft survive leaving and returning to a
    /// conversation (UX audit U4).
    @State private var conversationDrafts: [ConversationIdentity: String] = [:]
    /// The ready-to-render settings state.
    @State private var settingsState: SettingsState?
    /// The user's explicit provider selection for the presented conversation,
    /// restored from the persisted configuration and changed from the
    /// conversation screen's provider selector (UX audit V2).
    @State private var selectedProvider: ProviderIdentity?
    /// The streaming task of the active send-message flow.
    @State private var streamingTask: Task<Void, Never>?

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
                        case .settings:
                            settingsScreen
                        case nil:
                            EmptyView()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: openSettings) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel(Text("Settings"))
                    }
                }
                .task {
                    await loadSettings()
                }
                .task(id: navigation.currentRoute) {
                    guard navigation.currentRoute == .conversationList else { return }
                    streamingTask?.cancel()
                    streamingTask = nil
                    await loadConversationList()
                }
                .onChange(of: providerSelection) { selection in
                    if let screenState {
                        self.screenState = screenState.replacingProviderSelection(selection)
                    }
                }
            }
            .disabled(isMenuPresented)

            if isMenuPresented {
                drawer
            }
        }
        .animation(OmniaTheme.Motion.drawer, value: isMenuPresented)
    }

    /// The presented navigation drawer: the dim backdrop that closes it and the
    /// slide-in panel over the shell (new_design.md §7).
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
                onOpenConversations: {
                    closeMenu(route: .conversationList)
                },
                onOpenSettings: {
                    closeMenu(route: .settings)
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
                case .settings:
                    return .settings
                }
            },
            set: { value in
                navigation = NavigationState(currentRoute: value?.route ?? .conversationList)
            }
        )
    }

    private func conversationScreen(for identity: ConversationIdentity) -> some View {
        ConversationScreenView(
            state: screenState ?? ConversationScreenState(messages: []),
            draft: draftBinding,
            onSend: send,
            onCancel: cancel,
            onRegenerate: regenerate(at:),
            onCopy: copy(at:),
            onSelectProvider: { selectProvider($0.identity) }
        )
        .navigationTitle(title(for: identity))
        .onDisappear {
            streamingTask?.cancel()
            streamingTask = nil
        }
    }

    /// A binding to the rendered draft of the presented conversation's state:
    /// typing edits `screenState.draft` directly and records the in-progress
    /// draft per conversation, so an unsent draft is never lost when the
    /// conversation is left and reopened (UX audit U4).
    private var draftBinding: Binding<String> {
        Binding(
            get: { screenState?.draft ?? "" },
            set: { draft in
                if case .conversationScreen(let identity) = navigation.currentRoute {
                    conversationDrafts[identity] = draft
                }
                screenState = screenState?.replacingDraft(draft)
            }
        )
    }

    @ViewBuilder
    private var settingsScreen: some View {
        if let settingsState {
            SettingsView(
                state: settingsState,
                onCompose: presentConnectionForm,
                onCancel: dismissConnectionForm,
                onConfigure: configure,
                onEditProvider: editProvider,
                onEditModel: editModel,
                onResetConfiguration: resetConfiguration,
                onUpdateEndpoint: updateEndpoint,
                onUpdateModel: updateModel,
                onCancelEndpointEdit: cancelEndpointEdit,
                onCancelModelEdit: cancelModelEdit,
                onRemove: remove
            )
        } else {
            loadingState
                .navigationTitle("Settings")
        }
    }

    /// The navigation title of the conversation screen: the conversation's
    /// display title, derived by the presentation value type (DES-012 §3.1),
    /// with a fallback for a conversation without content.
    private func title(for identity: ConversationIdentity) -> String {
        guard let conversation = presentedConversation, conversation.identity == identity else {
            return "Conversation"
        }
        let title = ConversationListItem(conversation: conversation).displayTitle
        return title.isEmpty ? "Conversation" : title
    }

    // MARK: Loading

    /// The loading state shown until the first load resolves: a centered
    /// progress indicator, distinct from the loaded-but-empty state, so no
    /// empty-state flash appears while the conversation list or the settings
    /// load (UX audit U6). The pattern matches the shells' launch loading state.
    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text("Loading"))
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
                presentedConversation = conversation
                screenState = rendering(surface.conversationScreen.load(conversation))
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
                presentedConversation = conversation
                screenState = rendering(surface.conversationScreen.load(conversation))
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
                try await surface.conversationList.delete(identity)
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
        let history = (screenState?.messages ?? []) + [MessagePresentation(message: message)]
        streamingTask = Task { @MainActor in
            do {
                for try await state in surface.conversationScreen.send(request, rendering: history) {
                    screenState = rendering(state).replacingDraft(conversationDrafts[identity] ?? "")
                }
            } catch {
                if error is CancellationError { return }
                await presentUnexpectedStreamFailure()
            }
        }
    }

    /// Translates the cancel intent of an active stream: the stream is stopped,
    /// and the rendered state becomes the interrupted condition the Domain
    /// preserved — the partial content is rendered as incomplete, never
    /// discarded (ARC-001) — so the screen announces the interruption and the
    /// Stop affordance gives way to the composer (UX audit A4).
    private func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        guard let state = screenState, case .active(let partialContent) = state.streamingCondition else {
            return
        }
        screenState = state.replacingStreamingCondition(.interrupted(partialContent: partialContent))
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
              let messages = screenState?.messages,
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
        streamingTask = Task { @MainActor in
            do {
                for try await state in surface.conversationScreen.send(request, rendering: history) {
                    screenState = rendering(state).replacingDraft(conversationDrafts[identity] ?? "")
                }
            } catch {
                if error is CancellationError { return }
                await presentUnexpectedStreamFailure()
            }
        }
    }

    /// Translates the copy intent of an assistant message at the given index:
    /// its plain text is copied to the platform pasteboard — the user's own
    /// content (ARC-005).
    private func copy(at index: Int) {
        guard let messages = screenState?.messages,
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

    /// Presents an unexpected stream failure as a terminal failure on the
    /// screen: the conversation is reloaded — the Domain preserved the partial
    /// content as interrupted, which the screen renders as incomplete, never
    /// discarded (ARC-001, DES-009 §3.11.4) — and a `.unexpected` failure state
    /// is set on it, so the interruption reason is visible and distinct from a
    /// user-initiated cancellation, never silent (UX audit S1, ARC-001).
    @MainActor
    private func presentUnexpectedStreamFailure() async {
        guard case .conversationScreen(let identity) = navigation.currentRoute else { return }
        guard let conversation = try? await surface.conversationList.select(identity) else { return }
        presentedConversation = conversation
        let loaded = surface.conversationScreen.load(conversation)
        screenState = rendering(ConversationScreenState(
            messages: loaded.messages,
            draft: conversationDrafts[identity] ?? "",
            streamingCondition: loaded.streamingCondition,
            failure: .unexpected
        ))
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

    /// Translates the open-settings intent of the navigation chrome: the shell
    /// routes to the settings surface (DES-012 §3.5).
    private func openSettings() {
        navigation = NavigationState(currentRoute: .settings)
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

    /// Translates the endpoint-edit intent: the connection's recorded endpoint
    /// is resolved through the settings surface and the endpoint-edit condition
    /// of the settings state is presented — the editor pre-filled with the
    /// current endpoint, so a provider connection offers a way to edit instead
    /// of only Remove (UX audit U7). The condition holds only the configured
    /// connection state and the recorded endpoint, never a credential
    /// (ARC-001, ARC-005).
    private func editProvider(_ item: ProviderConnectionListItem) {
        Task { @MainActor in
            do {
                let endpoint = try await surface.settings.endpoint(for: item.identity)
                guard let current = settingsState else { return }
                settingsState = SettingsState(
                    connections: current.connections,
                    configuration: current.configuration,
                    isComposing: false,
                    editing: SettingsState.Editing(
                        identity: item.identity,
                        displayName: item.displayName,
                        currentEndpoint: endpoint ?? ""
                    )
                )
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the endpoint-update intent: the updated endpoint is recorded
    /// through the settings surface — validated at the service boundary before
    /// any write (DES-011 §3.9, ARC-009) — and the settings state reloads, so
    /// the endpoint editor closes and the connection row reflects the change.
    private func updateEndpoint(_ identity: ProviderIdentity, _ endpoint: String) {
        Task { @MainActor in
            do {
                try await surface.settings.updateEndpoint(endpoint, for: identity)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the cancel intent of the endpoint editor.
    private func cancelEndpointEdit() {
        guard let current = settingsState else { return }
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: false,
            editing: nil
        )
    }

    /// Translates the model-edit intent: the connection's recorded model is
    /// resolved through the settings surface and the model-edit condition of
    /// the settings state is presented — the editor pre-filled with the
    /// current model, mirroring the endpoint editor's retry/edit affordance.
    /// The condition holds only the configured connection state and the
    /// recorded model, never a credential (ARC-001, ARC-005).
    private func editModel(_ item: ProviderConnectionListItem) {
        Task { @MainActor in
            do {
                let model = try await surface.settings.model(for: item.identity)
                guard let current = settingsState else { return }
                settingsState = SettingsState(
                    connections: current.connections,
                    configuration: current.configuration,
                    isComposing: false,
                    editing: nil,
                    editingModel: SettingsState.ModelEditing(
                        identity: item.identity,
                        displayName: item.displayName,
                        currentModel: model ?? ""
                    )
                )
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the model-update intent: the updated model is recorded
    /// through the settings surface — validated at the service boundary before
    /// any write (DES-011 §3.10, ARC-009) — and the settings state reloads, so
    /// the model editor closes and the connection's recorded model reflects
    /// the change.
    private func updateModel(_ identity: ProviderIdentity, _ model: String) {
        Task { @MainActor in
            do {
                try await surface.settings.updateModel(model, for: identity)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the cancel intent of the model editor.
    private func cancelModelEdit() {
        guard let current = settingsState else { return }
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: false,
            editing: nil,
            editingModel: nil
        )
    }

    /// Translates the reset intent: the configuration value is removed at the
    /// user-owned workspace level, and the settings state reloads (DES-011
    /// §3.5).
    private func resetConfiguration(_ key: ConfigurationKey<String>) {
        Task { @MainActor in
            do {
                try await surface.settings.remove(key, at: .workspaceOverride)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Composes the settings state presenting the typed failure of a settings
    /// operation, as it is, never wrapped (DES-011 §3.6, DES-009 §3.9). The
    /// compose condition is preserved: a failed configure keeps the
    /// connection form presented with its input retained, so the failure is
    /// shown inside the form and no declaration is lost (UX audit U3). The
    /// endpoint-edit condition is preserved: a failed endpoint update keeps
    /// the endpoint editor presented with its input retained (UX audit U7).
    /// The model-edit condition is preserved: a failed model update keeps the
    /// model editor presented with its input retained.
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
            editingModel: settingsState?.editingModel,
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
    case settings

    /// The frozen route this destination presents.
    var route: NavigationState.Route {
        switch self {
        case .conversation(let conversation):
            return .conversationScreen(conversation: conversation)
        case .settings:
            return .settings
        }
    }
}

#endif
