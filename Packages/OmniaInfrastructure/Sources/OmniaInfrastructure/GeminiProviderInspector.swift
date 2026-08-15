import Foundation
import OmniaDomain

/// Gemini (Generative Language API) model discovery and connection validation.
///
/// The inspector is bound to one endpoint and credential. It returns only
/// Domain model identities and safe typed errors; HTTP bodies, private URLs,
/// authorization headers, and credential values never cross this boundary
/// (ARC-004, ARC-005).
///
/// Gemini's `GET /models` list is authoritative for the provider's catalog and
/// already validates the credential (an invalid key is rejected by the models
/// endpoint), so `testConnection` verifies the recorded model against the real
/// list without fabricating a fallback success path.
public struct GeminiProviderInspector: ProviderInspector, Sendable {
    private let client: GeminiClient
    private let endpoint: URL
    private let credential: CredentialReference

    public init(
        endpoint: URL,
        credential: CredentialReference,
        credentialStorage: any CredentialStorageProtocol
    ) {
        self.client = GeminiClient(
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
        self.client = GeminiClient(
            transport: URLSessionProviderTransport(),
            credentialStorage: storage
        )
        self.endpoint = endpoint
        self.credential = CredentialReference()
    }

    /// Transport-seam initializer used by deterministic package tests.
    internal init(
        client: GeminiClient,
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
            let models = try await client.models(endpoint: endpoint, credential: credential)
            if let model, !models.contains(model) {
                throw ProviderConnectionTestError.modelUnavailable
            }
            return models
        } catch let error as ProviderConnectionTestError {
            throw error
        } catch is CredentialStorageError {
            throw ProviderConnectionTestError.invalidCredential
        } catch let error as ProviderTransportError {
            throw ProviderErrorMapping.connectionError(from: error)
        }
    }
}
