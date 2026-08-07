#if canImport(SwiftUI)

import OmniaApplication
import SwiftUI

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
/// review against `.ai/standards/UI.md`. It requires NavigationStack (iOS 16,
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
    /// The ready-to-render conversation list state.
    @State private var listState: ConversationListState?
    /// The conversation the conversation screen presents.
    @State private var presentedConversation: Conversation?
    /// The ready-to-render conversation screen state.
    @State private var screenState: ConversationScreenState?
    /// The ready-to-render settings state.
    @State private var settingsState: SettingsState?
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

    public var body: some View {
        NavigationStack {
            ConversationListView(
                state: listState ?? ConversationListState(items: []),
                onCreate: createConversation,
                onSelect: openConversation,
                onDelete: deleteConversation
            )
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
                    Button {
                        navigation = NavigationState(currentRoute: .settings)
                    } label: {
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
        }
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
            onSend: send,
            onCancel: cancel
        )
        .navigationTitle(title(for: identity))
        .onDisappear {
            streamingTask?.cancel()
            streamingTask = nil
        }
    }

    private var settingsScreen: some View {
        SettingsView(
            state: settingsState ?? SettingsState(connections: [], configuration: []),
            onCompose: presentConnectionForm,
            onCancel: dismissConnectionForm,
            onConfigure: configure,
            onRemove: remove,
            onResetConfiguration: resetConfiguration
        )
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
                screenState = surface.conversationScreen.load(conversation)
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
                screenState = surface.conversationScreen.load(conversation)
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
        let request = SendMessageRequest(conversation: identity, message: message)
        let history = (screenState?.messages ?? []) + [MessagePresentation(message: message)]
        streamingTask = Task { @MainActor in
            do {
                for try await state in surface.conversationScreen.send(request, rendering: history) {
                    screenState = state
                }
            } catch {
                if error is CancellationError { return }
                await reloadPresentedConversation()
            }
        }
    }

    /// Translates the cancel intent of an active stream.
    private func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
    }

    /// Reloads the presented conversation after an unexpected stream failure:
    /// the Domain preserved the partial content as interrupted, which the
    /// screen renders as incomplete — never discarded (ARC-001, DES-009
    /// §3.11.4).
    @MainActor
    private func reloadPresentedConversation() async {
        guard case .conversationScreen(let identity) = navigation.currentRoute else { return }
        guard let conversation = try? await surface.conversationList.select(identity) else { return }
        presentedConversation = conversation
        screenState = surface.conversationScreen.load(conversation)
    }

    // MARK: Settings intents

    /// Translates the compose intent: the connection-form condition of the
    /// settings state is presented (DES-012 §3.4).
    private func presentConnectionForm() {
        guard let current = settingsState else { return }
        settingsState = SettingsState(
            connections: current.connections,
            configuration: current.configuration,
            isComposing: true
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

    /// Translates the configure intent: the composed request and the declared
    /// endpoint are handed to the settings surface — the entered secret enters
    /// only the frozen `ConfigureProviderRequest`, never any rendered state
    /// (ARC-001, ARC-005) — and the settings state reloads.
    private func configure(_ request: ConfigureProviderRequest, endpoint: String) {
        Task { @MainActor in
            do {
                _ = try await surface.settings.configure(request, endpoint: endpoint)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
    }

    /// Translates the remove intent — the user's removal of their own content
    /// and its stored credential (ARC-005) — and reloads the settings state.
    private func remove(_ identity: ProviderIdentity) {
        Task { @MainActor in
            do {
                try await surface.settings.remove(identity)
                await loadSettings()
            } catch {
                settingsState = failingSettingsState(error)
            }
        }
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
    /// operation, as it is, never wrapped (DES-011 §3.6, DES-009 §3.9).
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
            isComposing: false,
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
