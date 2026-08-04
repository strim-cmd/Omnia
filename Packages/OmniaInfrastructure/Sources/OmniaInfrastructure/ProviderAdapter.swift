import Foundation
import OmniaDomain

/// The provider adapter shell for OpenAI-compatible endpoints (DES-010 §3.6,
/// ARC-004).
///
/// The adapter conforms to the Domain capability contracts — text generation,
/// conversation, and streaming — realizing the capabilities the OpenAI-
/// compatible provider delivers (DES-009 §3.1). It wires the provider transport
/// and the credential storage to the contracts the application consumes, and is
/// bound by the Composition Root to a provider connection's endpoint and
/// stored credential (ARC-006, ARC-009).
///
/// It is a shell: it owns no business logic and no application state (ARC-004
/// Adapter Model). The concrete capability call methods are held back until the
/// Domain capability contract is extended (DES-010 §3.6, ARC-004, DES-009
/// §3.1); the transport seam is wired now so the adapter is testable without a
/// network (ARC-001, ARC-006). Live availability is reported here, by the
/// Infrastructure layer, never by the Domain (ARC-004 Capability Discovery,
/// DES-009 §3.1). Provider-specific code is confined to this adapter; provider
/// APIs never leave the package (ARC-004, ARC-009).
public struct OpenAICompatibleProviderAdapter:
    TextGenerationContract,
    ConversationContract,
    StreamingContract,
    Sendable
{
    private let client: OpenAICompatibleClient
    private let endpoint: URL
    private let credential: CredentialReference

    /// Creates the adapter over the default `URLSession` transport and
    /// `credentialStorage`, bound to the OpenAI-compatible `endpoint` and the
    /// provider's stored `credential`.
    ///
    /// The credential is held by reference; the raw secret is resolved only
    /// when a request is built and never enters logs or metadata (ARC-001,
    /// ARC-005).
    public init(
        endpoint: URL,
        credential: CredentialReference,
        credentialStorage: any CredentialStorageProtocol
    ) {
        self.init(
            client: OpenAICompatibleClient(
                transport: URLSessionProviderTransport(),
                credentialStorage: credentialStorage
            ),
            endpoint: endpoint,
            credential: credential
        )
    }

    /// Creates the adapter over an injected client; used by tests through the
    /// transport seam and by the Composition Root to bind a specific transport
    /// (ARC-001, ARC-006, ARC-009).
    internal init(
        client: OpenAICompatibleClient,
        endpoint: URL,
        credential: CredentialReference
    ) {
        self.client = client
        self.endpoint = endpoint
        self.credential = credential
    }

    /// Reports whether the provider can currently be reached and used.
    ///
    /// The report is produced by the Infrastructure layer, never by the Domain
    /// (ARC-004 Capability Discovery): it resolves the credential and probes
    /// the endpoint through the transport seam, and reports `false` on any
    /// credential or transport failure without leaking raw values.
    public func isAvailable() async -> Bool {
        await client.probeAvailability(endpoint: endpoint, credential: credential)
    }
}
