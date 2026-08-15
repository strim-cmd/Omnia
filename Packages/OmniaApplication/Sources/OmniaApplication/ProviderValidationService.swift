import Foundation
import OmniaDomain

/// Candidate values required to test a provider form without persisting it.
public struct ProviderConnectionTestRequest: Sendable {
    public let provider: ProviderIdentity?
    public let endpoint: String
    public let model: String?
    public let credential: Credential?
    /// The API family the candidate connection targets; the family selects
    /// which Infrastructure inspector validates it (ARC-004, DES-011 §3.4).
    public let apiKind: ProviderAPIKind

    public init(
        provider: ProviderIdentity? = nil,
        endpoint: String,
        model: String? = nil,
        credential: Credential? = nil,
        apiKind: ProviderAPIKind = ProviderAPIKind.default
    ) {
        self.provider = provider
        self.endpoint = endpoint
        self.model = model
        self.credential = credential
        self.apiKind = apiKind
    }
}

public struct ProviderConnectionTestResult: Equatable, Sendable {
    public let models: [ModelReference]

    public init(models: [ModelReference]) {
        self.models = models
    }
}

/// Validates either an unsaved provider candidate or an existing connection
/// through injected transport paths selected by the connection's API family.
public struct ProviderValidationService: Sendable {
    private let testCandidate: @Sendable (
        URL,
        Credential,
        ModelReference?,
        ProviderAPIKind
    ) async throws -> [ModelReference]
    private let testExisting: @Sendable (
        ProviderIdentity,
        URL,
        ModelReference?,
        ProviderAPIKind
    ) async throws -> [ModelReference]

    public init(
        testCandidate: @escaping @Sendable (
            URL,
            Credential,
            ModelReference?,
            ProviderAPIKind
        ) async throws -> [ModelReference],
        testExisting: @escaping @Sendable (
            ProviderIdentity,
            URL,
            ModelReference?,
            ProviderAPIKind
        ) async throws -> [ModelReference]
    ) {
        self.testCandidate = testCandidate
        self.testExisting = testExisting
    }

    public func test(
        _ request: ProviderConnectionTestRequest
    ) async throws -> ProviderConnectionTestResult {
        let trimmedEndpoint = request.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedEndpoint),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host != nil
        else {
            throw ProviderConnectionTestError.invalidEndpoint
        }
        let model = request.model?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = model.flatMap { $0.isEmpty ? nil : ModelReference(name: $0) }
        let models: [ModelReference]
        if let provider = request.provider {
            models = try await testExisting(provider, url, reference, request.apiKind)
        } else {
            guard let credential = request.credential else {
                throw ProviderConnectionTestError.invalidCredential
            }
            models = try await testCandidate(url, credential, reference, request.apiKind)
        }
        return ProviderConnectionTestResult(models: models)
    }
}
