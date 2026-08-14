import Foundation
import OmniaDomain

/// Generic OpenAI-compatible model discovery and connection validation.
///
/// The inspector is bound to one endpoint and credential. It returns only
/// Domain model identities and safe typed errors; HTTP bodies, private URLs,
/// authorization headers, and credential values never cross this boundary.
public struct OpenAICompatibleProviderInspector: Sendable {
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
            throw Self.catalogError(from: error)
        } catch let error as ProviderTransportError {
            throw Self.catalogError(from: error)
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
            throw Self.connectionError(from: error)
        }
    }

    private static func catalogError(
        from error: CredentialStorageError
    ) -> ModelCatalogError {
        switch error {
        case .credentialNotFound, .storageUnavailable:
            return .unauthorized
        }
    }

    private static func catalogError(
        from error: ProviderTransportError
    ) -> ModelCatalogError {
        switch error {
        case .invalidRequest, .invalidResponse:
            return .invalidResponse
        case .networkFailure:
            return .unreachable
        case .timedOut:
            return .timedOut
        case .httpStatus(let code):
            switch code {
            case 401, 403: return .unauthorized
            case 404, 405, 501: return .unsupported
            case 408, 504: return .timedOut
            case 429: return .rateLimited
            case 500...599: return .serverFailure
            default: return .invalidResponse
            }
        }
    }

    private static func connectionError(
        from error: ProviderTransportError
    ) -> ProviderConnectionTestError {
        switch error {
        case .invalidRequest:
            return .invalidEndpoint
        case .invalidResponse:
            return .invalidResponse
        case .networkFailure:
            return .unreachable
        case .timedOut:
            return .timedOut
        case .httpStatus(let code):
            switch code {
            case 401, 403: return .invalidCredential
            case 404, 405: return .invalidEndpoint
            case 408, 504: return .timedOut
            case 429: return .rateLimited
            case 500...599: return .serverFailure
            default: return .invalidResponse
            }
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
        return connectionError(from: error)
    }
}

/// Credential source used only for an unsaved Test Connection request.
private struct FixedCredentialStorage: CredentialStorageProtocol, Sendable {
    let credentialValue: Credential

    init(credential: Credential) {
        self.credentialValue = credential
    }

    func store(_ credential: Credential, for reference: CredentialReference) async throws {}

    func credential(for reference: CredentialReference) async throws -> Credential {
        credentialValue
    }

    func removeCredential(for reference: CredentialReference) async throws {}
}
