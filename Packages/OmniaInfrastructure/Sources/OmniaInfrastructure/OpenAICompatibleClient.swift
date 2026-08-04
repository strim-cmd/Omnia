import Foundation
import OmniaDomain

/// The OpenAI-compatible client over the transport seam (DES-010 §3.5).
///
/// The client constructs chat-completions requests for OpenAI-compatible
/// endpoints, decodes responses, and delivers streaming content, translating
/// every failure into `ProviderTransportError` (ARC-004, DES-009 §3.9). It is
/// internal to the package; the provider adapters consume it.
///
/// Authentication is by reference: the client resolves the credential through
/// the credential storage and builds the authorization header inside the
/// credential's scoped access, so the secret never enters logs, analytics, or
/// request metadata beyond the authorization header itself (ARC-001, ARC-005).
internal struct OpenAICompatibleClient: Sendable {
    private let transport: any ProviderTransport
    private let credentialStorage: any CredentialStorageProtocol

    init(
        transport: any ProviderTransport,
        credentialStorage: any CredentialStorageProtocol
    ) {
        self.transport = transport
        self.credentialStorage = credentialStorage
    }

    /// Performs a non-streaming chat-completions request and returns the
    /// decoded response.
    ///
    /// - Throws: `CredentialStorageError` when the credential cannot be
    ///   resolved, and `ProviderTransportError` for transport and decoding
    ///   failures.
    func chatCompletions(
        request: ChatCompletionRequest,
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> ChatCompletionResponse {
        let httpRequest = try await makeRequest(
            request: request,
            endpoint: endpoint,
            credential: credential,
            streaming: false
        )
        let response = try await transport.send(httpRequest)
        do {
            return try Self.jsonDecoder.decode(ChatCompletionResponse.self, from: response.body)
        } catch {
            throw ProviderTransportError.invalidResponse
        }
    }

    /// Performs a streaming chat-completions request and returns the decoded
    /// chunk stream.
    ///
    /// The stream yields one `ChatCompletionChunk` per SSE data event and ends
    /// at the `[DONE]` marker or when the transport stream ends. Throws
    /// `CredentialStorageError` when the credential cannot be resolved.
    func streamChatCompletions(
        request: ChatCompletionRequest,
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> AsyncThrowingStream<ChatCompletionChunk, any Error> {
        let httpRequest = try await makeRequest(
            request: request,
            endpoint: endpoint,
            credential: credential,
            streaming: true
        )
        return Self.chunkStream(from: transport.stream(httpRequest))
    }

    private func makeRequest(
        request: ChatCompletionRequest,
        endpoint: URL,
        credential: CredentialReference,
        streaming: Bool
    ) async throws -> ProviderHTTPRequest {
        let stored = try await credentialStorage.credential(for: credential)
        return try stored.withValue { apiKey in
            var request = request
            request.stream = streaming
            let body: Data
            do {
                body = try Self.jsonEncoder.encode(request)
            } catch {
                throw ProviderTransportError.invalidRequest
            }
            return ProviderHTTPRequest(
                url: endpoint.appendingPathComponent("chat/completions"),
                method: "POST",
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(apiKey)",
                ],
                body: body
            )
        }
    }

    private static func chunkStream(
        from chunks: AsyncThrowingStream<Data, any Error>
    ) -> AsyncThrowingStream<ChatCompletionChunk, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var decoder = SSEDecoder()
                do {
                    for try await chunk in chunks {
                        if !emit(decoder.append(chunk), to: continuation) {
                            return
                        }
                    }
                    if !emit(decoder.finish(), to: continuation) {
                        return
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Yields the decoded chunks of `events`; returns `false` after the `[DONE]`
    /// marker ends the stream.
    private static func emit(
        _ events: [SSEEvent],
        to continuation: AsyncThrowingStream<ChatCompletionChunk, any Error>.Continuation
    ) -> Bool {
        for event in events {
            if event.data.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                continuation.finish()
                return false
            }
            do {
                continuation.yield(
                    try Self.jsonDecoder.decode(
                        ChatCompletionChunk.self,
                        from: Data(event.data.utf8)
                    )
                )
            } catch {
                continuation.finish(throwing: ProviderTransportError.invalidResponse)
                return false
            }
        }
        return true
    }

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var jsonDecoder: JSONDecoder {
        JSONDecoder()
    }
}
