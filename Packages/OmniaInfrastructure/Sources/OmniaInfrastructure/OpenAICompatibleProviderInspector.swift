import Foundation
import OmniaDomain

/// Generic OpenAI-compatible model discovery and connection validation.
///
/// The inspector is bound to one endpoint and credential. It returns only
/// Domain model identities and safe typed errors; HTTP bodies, private URLs,
/// authorization headers, and credential values never cross this boundary.
public struct OpenAICompatibleProviderInspector: ProviderInspector, Sendable {
    private let client: OpenAICompatibleClient
    private let endpoint: URL
    private let credential: CredentialReference

    public init(
        endpoint: URL,
        credential: CredentialReference,
        credentialStorage: any CredentialStorageProtocol
    ) {
        self.client = OpenAICompatibleClient(
            transport: URLSessionProviderTransport(),
            credentialStorage: credentialStorage
        )
        self.endpoint = endpoint
        self.credential = credential
    }

    /// Creates a non-persisting inspector for a provider form's candidate
    /// credential. The credential remains opaque and is never written.
    public init(endpoint: URL, credential: Credential) {
        let storage = FixedCredentialStorage(credential: credential)
        self.client = OpenAICompatibleClient(
            transport: URLSessionProviderTransport(),
            credentialStorage: storage
        )
        self.endpoint = endpoint
        self.credential = CredentialReference()
    }

    /// Transport-seam initializer used by deterministic package tests.
    internal init(
        client: OpenAICompatibleClient,
        endpoint: URL,
        credential: CredentialReference
    ) {
        self.client = client
        self.endpoint = endpoint
        self.credential = credential
    }

    public func discoverModels() async throws -> [ModelReference] {
        do {
            return try await client.models(endpoint: endpoint, credential: credential)
        } catch let error as CredentialStorageError {
            throw ProviderErrorMapping.catalogError(from: error)
        } catch let error as ProviderTransportError {
            throw ProviderErrorMapping.catalogError(from: error)
        }
    }

    public func testConnection(
        model: ModelReference?
    ) async throws -> [ModelReference] {
        do {
            let models = try await client.models(
                endpoint: endpoint,
                credential: credential
            )
            if let model, !models.contains(model) {
                throw ProviderConnectionTestError.modelUnavailable
            }
            return models
        } catch let error as ProviderConnectionTestError {
            throw error
        } catch let error as ProviderTransportError
            where Self.discoveryIsUnsupported(error) && model != nil {
            guard let model else { throw ProviderConnectionTestError.invalidEndpoint }
            // Some OpenAI-compatible endpoints intentionally omit `/models`.
            // A bounded one-token chat request validates the actual configured
            // model/credential path instead of treating manual fallback as fake
            // success.
            do {
                _ = try await client.chatCompletions(
                    request: ChatCompletionRequest(
                        model: model.name,
                        messages: [ChatMessage(role: "user", content: "OK")],
                        stream: false,
                        temperature: nil,
                        maxTokens: 1
                    ),
                    endpoint: endpoint,
                    credential: credential
                )
                return [model]
            } catch is CredentialStorageError {
                throw ProviderConnectionTestError.invalidCredential
            } catch let validationError as ProviderTransportError {
                throw Self.manualModelConnectionError(from: validationError)
            }
        } catch is CredentialStorageError {
            throw ProviderConnectionTestError.invalidCredential
        } catch let error as ProviderTransportError {
            throw ProviderErrorMapping.connectionError(from: error)
        }
    }

    private static func discoveryIsUnsupported(
        _ error: ProviderTransportError
    ) -> Bool {
        guard case .httpStatus(let code) = error else { return false }
        return code == 404 || code == 405 || code == 501
    }

    private static func manualModelConnectionError(
        from error: ProviderTransportError
    ) -> ProviderConnectionTestError {
        if case .httpStatus(let code) = error, code == 400 || code == 404 {
            return .modelUnavailable
        }
        return ProviderErrorMapping.connectionError(from: error)
    }
}
