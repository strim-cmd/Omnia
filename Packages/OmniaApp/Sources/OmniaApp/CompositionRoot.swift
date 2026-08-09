import Foundation
import OmniaApplication
import OmniaDomain
import OmniaInfrastructure
import OmniaPresentation

/// The Composition Root of the application (DES-013 §3.1): the only place where
/// Infrastructure implementations are referenced, and the assembler of the
/// object graph.
///
/// It constructs the storage layout, the four file repositories, the secure
/// credential storage, the application services, the provider lifecycle and
/// selection services, the runtime provider adapter binding, and the
/// presentation surfaces (DES-012 §3.6, ARC-006). It owns assembly only
/// (ARC-009): each Infrastructure implementation is referenced in exactly one
/// place, and the graph is delivered as the frozen contracts and services of the
/// Domain, Application, and Presentation layers.
///
/// `prepare()` is the composition's wiring of the graph to the running state: it
/// registers the stored provider connections in the lifecycle service and
/// transitions them to ready, so selection and the runtime binding can serve
/// them, and it runs the first-run bootstrap that resolves the default
/// workspace (DES-013 §3.3, §3.4). Both steps are idempotent across launches. A
/// provider configured during a running session is registered on the next
/// `prepare()`; the composition owns no other orchestration (ARC-009).
public struct CompositionRoot: Sendable {
    /// The storage root the file repositories are rooted at (DES-013 §3.2).
    public let storageRoot: URL

    /// The provider lifecycle service, in which `prepare()` registers the
    /// stored provider connections (DES-009 §3.2).
    public let lifecycleService: ProviderLifecycleService

    /// The provider selection service the send-message flow selects through
    /// (DES-009 §3.2).
    public let selectionService: ProviderSelectionService

    /// The runtime provider adapter binding, delivered to the send-message use
    /// case as the streaming contract and available to the composition for the
    /// text generation and conversation contracts (DES-013 §3.3).
    internal let binding: ProviderAdapterBinding

    /// The workspace application service.
    public let workspaceService: WorkspaceService

    /// The conversation application service.
    public let conversationService: ConversationService

    /// The provider connection application service.
    public let providerConnectionService: ProviderConnectionService

    /// The configuration application service.
    public let configurationService: ConfigurationService

    /// The send-message use case, delivered the runtime binding as its
    /// streaming contract.
    public let sendMessageUseCase: SendMessageUseCase

    /// The navigation surface hosting the conversation list, conversation
    /// screen, and settings surfaces (DES-012 §3.6).
    public let navigationSurface: NavigationSurface

    /// The file provider repository, read by `prepare()` to register the stored
    /// connections.
    private let providerRepository: any ProviderRepository

    /// The app-edge offered models of a provider: the recorded OpenAI-compatible
    /// model (the OmniRoute combo, or any provider model name) when the provider
    /// records one, falling back to the app-edge default model (DES-013 §3.3,
    /// DES-011 §3.10).
    ///
    /// The same closure is delivered to provider selection and to the runtime
    /// adapter binding, so selection and request routing always agree on which
    /// models a provider offers (DES-013 §3.3). A configuration read failure
    /// falls back to the app-edge default model — the same value the provider
    /// offers when no model is recorded — matching the documented behavior of
    /// DES-013 §3.3 (ARC-001).
    static func preferredModels(
        configurationService: ConfigurationService
    ) -> @Sendable (ProviderIdentity) async -> [ModelReference] {
        { identity in
            if let model = try? await configurationService.value(
                for: ProviderConnectionService.modelKey(for: identity),
                at: .providerSettings
            ) {
                return [ModelReference(name: model)]
            }
            return [ModelReference(name: AppEdgeConstants.defaultModelName)]
        }
    }

    /// Creates the composed object graph, rooted at `storageRoot` when given,
    /// otherwise at the platform Application Support storage root of
    /// `StorageLayout` (DES-013 §3.2).
    ///
    /// The root is derived once at composition; the repositories create their
    /// directories lazily on the first save, and credentials never enter any
    /// directory (ARC-005).
    public init(storageRoot: URL? = nil) {
        let root = storageRoot ?? StorageLayout.platformRoot()
        self.storageRoot = root

        let workspacesDirectory = root.appendingPathComponent("Workspaces", isDirectory: true)
        let conversationsDirectory = root.appendingPathComponent("Conversations", isDirectory: true)
        let providersDirectory = root.appendingPathComponent("Providers", isDirectory: true)
        let configurationDirectory = root.appendingPathComponent("Configuration", isDirectory: true)

        let workspaceRepository = FileWorkspaceRepository(directory: workspacesDirectory)
        let conversationRepository = FileConversationRepository(directory: conversationsDirectory)
        let providerRepository = FileProviderRepository(directory: providersDirectory)
        let configurationRepository = FileConfigurationRepository(directory: configurationDirectory)
        let credentialStorage = SecureCredentialStorage()

        let lifecycleService = ProviderLifecycleService()
        let configurationService = ConfigurationService(
            configurationRepository: configurationRepository,
            resolutionPolicy: ConfigurationResolutionPolicy()
        )
        let preferredModels = Self.preferredModels(configurationService: configurationService)
        let selectionService = ProviderSelectionService(
            lifecycleService: lifecycleService,
            preferredModels: preferredModels
        )
        let binding = ProviderAdapterBinding(
            lifecycleService: lifecycleService,
            configurationService: configurationService,
            credentialStorage: credentialStorage,
            preferredModels: preferredModels
        )
        let workspaceService = WorkspaceService(workspaceRepository: workspaceRepository)
        let conversationService = ConversationService(
            conversationRepository: conversationRepository,
            workspaceRepository: workspaceRepository
        )
        let providerConnectionService = ProviderConnectionService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let sendMessageUseCase = SendMessageUseCase(
            streamingContract: binding,
            selectionService: selectionService,
            conversationRepository: conversationRepository
        )

        self.lifecycleService = lifecycleService
        self.selectionService = selectionService
        self.binding = binding
        self.workspaceService = workspaceService
        self.conversationService = conversationService
        self.providerConnectionService = providerConnectionService
        self.configurationService = configurationService
        self.sendMessageUseCase = sendMessageUseCase
        self.providerRepository = providerRepository

        self.navigationSurface = NavigationSurface(
            conversationList: ConversationListSurface(service: conversationService),
            conversationScreen: ConversationScreenSurface(useCase: sendMessageUseCase),
            settings: SettingsSurface(
                connectionService: providerConnectionService,
                configurationService: configurationService
            )
        )
    }

    /// Wires the composed graph to the running state: registers the stored
    /// provider connections in the lifecycle service and transitions them to
    /// ready, and resolves the default workspace, creating it on first launch
    /// (DES-013 §3.3, §3.4).
    ///
    /// The operation is idempotent across launches: registration replaces any
    /// previously registered connection with the same identity, and the
    /// bootstrap re-resolves the recorded default workspace identity.
    ///
    /// - Returns: The resolved default workspace identity, delivered as session
    ///   state and as `RootView.workspace`.
    public func prepare() async throws -> WorkspaceIdentity {
        let providers = try await providerRepository.allProviders()
        for provider in providers {
            let identity = await lifecycleService.register(provider.connection)
            try await lifecycleService.transition(identity, to: .validated)
            try await lifecycleService.transition(identity, to: .initializing)
            try await lifecycleService.transition(identity, to: .ready)
        }
        let bootstrap = FirstRunBootstrap(
            workspaceService: workspaceService,
            configurationService: configurationService
        )
        return try await bootstrap.resolve()
    }
}
