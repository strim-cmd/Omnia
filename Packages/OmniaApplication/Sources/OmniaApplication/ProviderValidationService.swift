import Foundation
import OmniaDomain

/// Candidate values required to test a provider form without persisting it.
public struct ProviderConnectionTestRequest: Sendable {
    public let provider: ProviderIdentity?
    public let endpoint: String
    public let model: String?
    public let credential: Credential?

    public init(
        provider: ProviderIdentity? = nil,
        endpoint: String,
        model: String? = nil,
        credential: Credential? = nil
    ) {
        self.provider = provider
        self.endpoint = endpoint
        self.model = model
        self.credential = credential
    }
}

public struct ProviderConnectionTestResult: Equatable, Sendable {
    public let models: [ModelReference]

    public init(models: [ModelReference]) {
        self.models = models
    }
}

/// Validates either an unsaved provider candidate or an existing connection
/// through injected generic transport paths.
public struct ProviderValidationService: Sendable {
    private let testCandidate: @Sendable (
        URL,
        Credential,
        ModelReference?
    ) async throws -> [ModelReference]
    private let testExisting: @Sendable (
        ProviderIdentity,
        URL,
        ModelReference?
    ) async throws -> [ModelReference]

    public init(
        testCandidate: @escaping @Sendable (
            URL,
            Credential,
            ModelReference?
        ) async throws -> [ModelReference],
        testExisting: @escaping @Sendable (
            ProviderIdentity,
            URL,
            ModelReference?
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
            models = try await testExisting(provider, url, reference)
        } else {
            guard let credential = request.credential else {
                throw ProviderConnectionTestError.invalidCredential
            }
            models = try await testCandidate(url, credential, reference)
        }
        return ProviderConnectionTestResult(models: models)
    }
}
