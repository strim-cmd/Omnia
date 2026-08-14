import Foundation
import OmniaApplication
import OmniaDomain
import OmniaInfrastructure

/// The runtime provider adapter binding the Composition Root delivers as the
/// streaming, conversation, and text generation contracts (DES-013 §3.3,
/// ARC-006).
///
/// It is the object through which a request for a model reaches the provider
/// that serves it. On each call it resolves, among the ready providers known to
/// the lifecycle service, the deterministic provider that offers the requested
/// model — in the canonical identity order the selection policy applies (DES-009
/// §3.2) — reads that provider's recorded endpoint, credential reference, and
/// optional model from the provider-settings configuration through the
/// documented keys the settings surface writes (DES-011 §3.4, §3.9, §3.10), and
/// constructs, on demand, the `OpenAICompatibleProviderAdapter` bound to them
/// (DES-010 §3.6). A provider that records an OpenAI-compatible model (the
/// OmniRoute combo, or any provider model name) serves the request with that
/// recorded model; a provider with no recorded model serves the requested model
/// unchanged. The provider is never bound at composition time; each request is
/// served by an adapter constructed for the provider that serves its model, so a
/// stored provider with no recorded endpoint or credential is never silently
/// used (ARC-001).
///
/// The binding owns no business logic and no provider state (ARC-002, ARC-004):
/// provider selection and lifecycle are the Domain's, the adapter is the
/// Infrastructure's, and the binding only sequences the resolution and the
/// construction. A request no ready provider can serve surfaces
/// `CapabilityError.providerUnavailable` (ARC-004, DES-009 §3.11.2), and every
/// failure the adapter reports is passed through as it is, never wrapped
/// (DES-009 §3.9).
internal struct ProviderAdapterBinding: TextGenerationContract, ConversationContract, StreamingContract, Sendable {
    /// The lifecycle service: the set of ready providers the binding resolves
    /// among (DES-009 §3.2).
    private let lifecycleService: ProviderLifecycleService

    /// The configuration service: the provider-settings values the binding
    /// reads the endpoint and credential reference from (DES-013 §3.3).
    private let configurationService: ConfigurationService

    /// The app-edge offered models, the same closure the selection service uses,
    /// so the binding resolves the same providers selection considers (DES-013
    /// §3.3).
    private let preferredModels: @Sendable (ProviderIdentity) async -> [ModelReference]

    /// The adapter factory: the seam through which a bound
    /// `OpenAICompatibleProviderAdapter` is constructed for the resolved
    /// provider, so the binding is testable without a network (ARC-001,
    /// ARC-006).
    private let adapterFactory: @Sendable (URL, CredentialReference) async throws -> any TextGenerationContract & ConversationContract & StreamingContract

    /// Creates the binding over the given Domain and Application contracts,
    /// constructing each resolved provider's adapter over the default transport
    /// and `credentialStorage`.
    init(
        lifecycleService: ProviderLifecycleService,
        configurationService: ConfigurationService,
        credentialStorage: any CredentialStorageProtocol,
        preferredModels: @escaping @Sendable (ProviderIdentity) async -> [ModelReference]
    ) {
        self.init(
            lifecycleService: lifecycleService,
            configurationService: configurationService,
            preferredModels: preferredModels,
            adapterFactory: { endpoint, reference in
                OpenAICompatibleProviderAdapter(
                    endpoint: endpoint,
                    credential: reference,
                    credentialStorage: credentialStorage
                )
            }
        )
    }

    /// Creates the binding over an injected adapter factory; used by tests
    /// through the adapter seam.
    init(
        lifecycleService: ProviderLifecycleService,
        configurationService: ConfigurationService,
        preferredModels: @escaping @Sendable (ProviderIdentity) async -> [ModelReference],
        adapterFactory: @escaping @Sendable (URL, CredentialReference) async throws -> any TextGenerationContract & ConversationContract & StreamingContract
    ) {
        self.lifecycleService = lifecycleService
        self.configurationService = configurationService
        self.preferredModels = preferredModels
        self.adapterFactory = adapterFactory
    }

    public func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        let adapter = try await adapter(for: request.provider, model: request.model)
        return try await adapter.generateText(
            from: TextGenerationRequest(
                identity: request.identity,
                prompt: request.prompt,
                model: request.model,
                provider: request.provider
            )
        )
    }

    public func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        let adapter = try await adapter(for: request.provider, model: request.model)
        return try await adapter.sendMessage(
            ConversationRequest(
                identity: request.identity,
                history: request.history,
                model: request.model,
                provider: request.provider,
                resolvedAttachments: request.resolvedAttachments
            )
        )
    }

    public func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        let adapter = try await adapter(for: request.provider, model: request.model)
        return try await adapter.stream(
            StreamingRequest(
                identity: request.identity,
                history: request.history,
                model: request.model,
                provider: request.provider,
                resolvedAttachments: request.resolvedAttachments
            )
        )
    }

    /// Resolves the ready provider serving `model` and constructs the adapter
    /// bound to its recorded endpoint and credential reference (DES-013 §3.3).
    ///
    /// The endpoint string recorded by the settings surface has been validated
    /// at the application boundary as an absolute `http` or `https` URL (DES-011
    /// §3.9), so restoring it as a `URL` here never fails for a recorded value;
    /// a provider without a recorded endpoint or credential reference cannot
    /// serve the request and surfaces `CapabilityError.providerUnavailable`.
    ///
    /// A provider that records an OpenAI-compatible model (the OmniRoute combo,
    /// or any provider model name) serves the request with that recorded model;
    /// a provider with no recorded model serves the requested model unchanged
    /// (DES-011 §3.10, DES-013 §3.3).
    private func adapter(
        for requestedProvider: ProviderIdentity?,
        model: ModelReference
    ) async throws -> any TextGenerationContract & ConversationContract & StreamingContract {
        let offering = await readyProvidersOffering(model)
        let identity: ProviderIdentity
        if let requestedProvider {
            guard offering.contains(requestedProvider) else {
                throw CapabilityError.modelUnavailable(model: model)
            }
            identity = requestedProvider
        } else if let automatic = offering.first {
            identity = automatic
        } else {
            throw CapabilityError.providerUnavailable
        }
        guard
            let endpoint = try await configurationService.value(
                for: ProviderConnectionService.endpointKey(for: identity),
                at: .providerSettings
            ),
            let url = URL(string: endpoint)
        else {
            throw CapabilityError.providerUnavailable
        }
        guard
            let reference = try await configurationService.value(
                for: ProviderConnectionService.credentialReferenceKey(for: identity),
                at: .providerSettings
            )
        else {
            throw CapabilityError.providerUnavailable
        }
        return try await adapterFactory(url, reference)
    }

    /// The ready providers offering `model`, in canonical identity order — the
    /// deterministic ordering the selection policy applies when several
    /// candidates are eligible at the same step (DES-009 §3.2).
    private func readyProvidersOffering(_ model: ModelReference) async -> [ProviderIdentity] {
        let identities = await lifecycleService.allProviders()
        var offering: [ProviderIdentity] = []
        for identity in identities {
            guard await lifecycleService.state(of: identity) == .ready else { continue }
            if await preferredModels(identity).contains(model) {
                offering.append(identity)
            }
        }
        return offering.sorted { $0.canonicalString < $1.canonicalString }
    }
}
