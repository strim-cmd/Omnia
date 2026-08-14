import Foundation
import OmniaDomain

/// The provider adapter shell for OpenAI-compatible endpoints (DES-010 §3.6,
/// ARC-004).
///
/// The adapter wires the provider transport and the credential storage to the
/// capability contracts the application consumes, and is bound by the
/// Composition Root to a provider connection's endpoint and stored credential
/// (ARC-006, ARC-009).
///
/// It is a shell: it owns no business logic and no application state (ARC-004
/// Adapter Model), and the transport seam is wired now so the adapter is
/// testable without a network (ARC-001, ARC-006). The Domain capability
/// contract declares the concrete capability call methods (DES-009 §3.11.3);
/// the adapter realizes them over the transport seam: the text generation,
/// conversation, and streaming contracts (DES-010 §3.9.1, PRD-005). Live
/// availability is reported here, by the Infrastructure layer, never by the
/// Domain (ARC-004 Capability Discovery, DES-009 §3.1). Provider-specific code
/// is confined to this adapter; provider APIs never leave the package
/// (ARC-004, ARC-009).
public struct OpenAICompatibleProviderAdapter: TextGenerationContract, ConversationContract, StreamingContract, Sendable {
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

    /// Produces the generated text from `request` (DES-009 §3.11.3).
    ///
    /// Translates `request` through the adapter's mapping (DES-010 §3.9.2),
    /// performs the non-streaming chat-completions request through the injected
    /// client, and translates the wire response back to the Domain text
    /// generation response — composing the mapping and the client, and owning no
    /// business logic (ARC-004 Adapter Model, DES-010 §3.9.1). A transport or
    /// decoding failure is translated into the Domain capability error of
    /// DES-010 §3.9.3; a credential-resolution failure surfaces as the Domain
    /// `CredentialStorageError`, never wrapped (DES-009 §3.7, §3.9).
    public func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        let wireRequest = CapabilityMapping.request(from: request)
        let response: ChatCompletionResponse
        do {
            response = try await client.chatCompletions(
                request: wireRequest,
                endpoint: endpoint,
                credential: credential
            )
        } catch let error as ProviderTransportError {
            throw CapabilityMapping.capabilityError(from: error)
        }
        return try CapabilityMapping.textResponse(from: response)
    }

    /// Sends `request` and returns the assistant's reply (DES-009 §3.11.3).
    ///
    /// Translates `request` through the adapter's mapping (DES-010 §3.9.2),
    /// performs the non-streaming chat-completions request through the injected
    /// client with the message history, and translates the wire response back
    /// to the Domain conversation response — the assistant `Message` to append
    /// to the history — composing the mapping and the client, and owning no
    /// business logic (ARC-004 Adapter Model, DES-010 §3.9.1). A transport or
    /// decoding failure is translated into the Domain capability error of
    /// DES-010 §3.9.3; a credential-resolution failure surfaces as the Domain
    /// `CredentialStorageError`, never wrapped (DES-009 §3.7, §3.9).
    public func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        let wireRequest = try CapabilityMapping.request(from: request)
        let response: ChatCompletionResponse
        do {
            response = try await client.chatCompletions(
                request: wireRequest,
                endpoint: endpoint,
                credential: credential
            )
        } catch let error as ProviderTransportError {
            throw CapabilityMapping.capabilityError(from: error)
        }
        return try CapabilityMapping.conversationResponse(from: response)
    }

    /// Streams the reply to `request` as incremental updates (DES-009 §3.11.3).
    ///
    /// Translates `request` through the adapter's mapping (DES-010 §3.9.2),
    /// performs the streaming chat-completions request through the injected
    /// client, and delivers the client's chunk stream as the Domain streaming
    /// updates — composing the mapping and the client, and owning no business
    /// logic (ARC-004 Adapter Model, DES-010 §3.9.1). Each chunk's content delta
    /// becomes a `StreamingUpdate.contentDelta`; the end of the stream becomes
    /// the `StreamingUpdate.completion` carrying the assembled assistant message
    /// (DES-010 §3.9.4). A stream that stops because of cancellation — the
    /// Foundation cancellation primitive of DES-008, observed through the
    /// stream lifecycle — ends with the `StreamingUpdate.interruption` event
    /// carrying the preserved partial content, so partial content is never
    /// silently discarded (ARC-001). A streaming failure before a terminal event
    /// is translated into `CapabilityError.streamingInterrupted(partialContent:)`
    /// (DES-010 §3.9.3); a credential-resolution failure surfaces as the Domain
    /// `CredentialStorageError`, never wrapped (DES-009 §3.7, §3.9).
    public func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        let wireRequest = try CapabilityMapping.request(from: request)
        let chunkStream: AsyncThrowingStream<ChatCompletionChunk, any Error>
        do {
            chunkStream = try await client.streamChatCompletions(
                request: wireRequest,
                endpoint: endpoint,
                credential: credential
            )
        } catch let error as ProviderTransportError {
            throw CapabilityMapping.capabilityError(from: error)
        }
        let identity = request.identity
        return AsyncThrowingStream { continuation in
            let task = Task {
                var partialContent = ""
                do {
                    for try await chunk in chunkStream {
                        guard let delta = CapabilityMapping.update(from: chunk, identity: identity) else {
                            continue
                        }
                        guard case .contentDelta(_, let content) = delta else {
                            continue
                        }
                        partialContent += content
                        continuation.yield(delta)
                        if Task.isCancelled {
                            continuation.yield(.interruption(identity: identity, partialContent: partialContent))
                            continuation.finish()
                            return
                        }
                    }
                    if Task.isCancelled {
                        continuation.yield(.interruption(identity: identity, partialContent: partialContent))
                    } else {
                        let message = CapabilityMapping.streamCompletionMessage(from: partialContent)
                        continuation.yield(.completion(identity: identity, message: message))
                    }
                } catch is CancellationError {
                    continuation.yield(.interruption(identity: identity, partialContent: partialContent))
                } catch {
                    if Task.isCancelled {
                        continuation.yield(.interruption(identity: identity, partialContent: partialContent))
                    } else {
                        continuation.finish(throwing: CapabilityError.streamingInterrupted(partialContent: partialContent))
                        return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
