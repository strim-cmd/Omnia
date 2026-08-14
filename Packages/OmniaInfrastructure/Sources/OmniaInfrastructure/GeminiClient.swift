import Foundation
import OmniaDomain

/// The Gemini (Generative Language API) client over the transport seam
/// (DES-010 §3.5).
///
/// The client constructs Generate Content requests for Gemini endpoints,
/// decodes responses, and delivers streamed events, translating every failure
/// into `ProviderTransportError` (ARC-004, DES-009 §3.9). It is internal to the
/// package; the provider adapters consume it.
///
/// Authentication is by reference: the client resolves the credential through
/// the credential storage and sends it in the `x-goog-api-key` header, so the
/// secret never enters URLs, logs, analytics, or request metadata beyond the
/// header itself (ARC-001, ARC-005).
internal struct GeminiClient: Sendable {
    private let transport: any ProviderTransport
    private let credentialStorage: any CredentialStorageProtocol

    init(
        transport: any ProviderTransport,
        credentialStorage: any CredentialStorageProtocol
    ) {
        self.transport = transport
        self.credentialStorage = credentialStorage
    }

    /// Performs a non-streaming Generate Content request and returns the
    /// decoded response.
    ///
    /// - Throws: `CredentialStorageError` when the credential cannot be
    ///   resolved, and `ProviderTransportError` for transport and decoding
    ///   failures.
    func generateContent(
        request: GenerateContentRequest,
        model: String,
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> GenerateContentResponse {
        let httpRequest = try await makeRequest(
            request: request,
            model: model,
            endpoint: endpoint,
            credential: credential,
            streaming: false
        )
        let response = try await transport.send(httpRequest)
        do {
            return try Self.jsonDecoder.decode(GenerateContentResponse.self, from: response.body)
        } catch {
            throw ProviderTransportError.invalidResponse
        }
    }

    /// Performs a streaming Generate Content request and returns the decoded
    /// event stream.
    ///
    /// The stream yields one `GenerateContentResponse` per SSE data event and
    /// ends when the transport stream ends — Gemini sends no terminal marker.
    /// Throws `CredentialStorageError` when the credential cannot be resolved.
    func streamGenerateContent(
        request: GenerateContentRequest,
        model: String,
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> AsyncThrowingStream<GenerateContentResponse, any Error> {
        let httpRequest = try await makeRequest(
            request: request,
            model: model,
            endpoint: endpoint,
            credential: credential,
            streaming: true
        )
        return Self.eventStream(from: transport.stream(httpRequest))
    }

    /// Reports whether `endpoint` is reachable and authenticated (DES-010 §3.6).
    ///
    /// Resolves the credential and probes the endpoint through the transport
    /// seam with a minimal `GET /models` request; any credential or transport
    /// failure reports `false`, so raw values never surface and availability is
    /// reported by the Infrastructure layer in Omnia's own terms (ARC-004
    /// Capability Discovery, DES-009 §3.1).
    func probeAvailability(endpoint: URL, credential: CredentialReference) async -> Bool {
        do {
            _ = try await models(endpoint: endpoint, credential: credential)
            return true
        } catch {
            return false
        }
    }

    /// Loads the Gemini model list. Model-list records prove identity only;
    /// they intentionally produce no inferred vision/file facts. The `models/`
    /// prefix the API returns is stripped from each name.
    func models(
        endpoint: URL,
        credential: CredentialReference
    ) async throws -> [ModelReference] {
        let stored = try await credentialStorage.credential(for: credential)
        let request = stored.withValue { apiKey in
            ProviderHTTPRequest(
                url: endpoint.appendingPathComponent("models"),
                method: "GET",
                headers: ["x-goog-api-key": apiKey],
                body: nil
            )
        }
        let response = try await transport.send(request)
        let decoded: GeminiModelsResponse
        do {
            decoded = try Self.jsonDecoder.decode(GeminiModelsResponse.self, from: response.body)
        } catch {
            throw ProviderTransportError.invalidResponse
        }
        let prefix = "models/"
        let names = (decoded.models ?? [])
            .compactMap(\.name)
            .map { $0.hasPrefix(prefix) ? String($0.dropFirst(prefix.count)) : $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted().map(ModelReference.init(name:))
    }

    private func makeRequest(
        request: GenerateContentRequest,
        model: String,
        endpoint: URL,
        credential: CredentialReference,
        streaming: Bool
    ) async throws -> ProviderHTTPRequest {
        let stored = try await credentialStorage.credential(for: credential)
        return try stored.withValue { apiKey in
            let body: Data
            do {
                body = try Self.jsonEncoder.encode(request)
            } catch {
                throw ProviderTransportError.invalidRequest
            }
            let modelPath = model.hasPrefix("models/") ? String(model.dropFirst("models/".count)) : model
            var base = endpoint.absoluteString
            if base.hasSuffix("/") {
                base.removeLast()
            }
            let action = streaming ? "streamGenerateContent" : "generateContent"
            var urlString = "\(base)/models/\(modelPath):\(action)"
            if streaming {
                urlString += "?alt=sse"
            }
            guard let url = URL(string: urlString) else {
                throw ProviderTransportError.invalidRequest
            }
            return ProviderHTTPRequest(
                url: url,
                method: "POST",
                headers: [
                    "Content-Type": "application/json",
                    "x-goog-api-key": apiKey,
                ],
                body: body
            )
        }
    }

    private static func eventStream(
        from chunks: AsyncThrowingStream<Data, any Error>
    ) -> AsyncThrowingStream<GenerateContentResponse, any Error> {
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

    /// Yields the decoded events of `events`; returns `false` after an
    /// undecodable event ends the stream as `invalidResponse`.
    private static func emit(
        _ events: [SSEEvent],
        to continuation: AsyncThrowingStream<GenerateContentResponse, any Error>.Continuation
    ) -> Bool {
        for event in events {
            let payload = event.data.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty else {
                continue
            }
            do {
                continuation.yield(
                    try Self.jsonDecoder.decode(
                        GenerateContentResponse.self,
                        from: Data(payload.utf8)
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
