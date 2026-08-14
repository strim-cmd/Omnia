/// Safe, typed failures produced while discovering models.
public enum ModelCatalogError: Error, Equatable, Sendable {
    case unsupported
    case unauthorized
    case unreachable
    case rateLimited
    case timedOut
    case serverFailure
    case invalidResponse
}

/// Safe, typed outcomes of testing an OpenAI-compatible connection.
///
/// Cases intentionally carry no endpoint, credential, response body, or raw
/// provider detail, so descriptions and logs cannot expose secrets.
public enum ProviderConnectionTestError: Error, Equatable, Sendable {
    case invalidCredential
    case unreachable
    case invalidEndpoint
    case modelUnavailable
    case rateLimited
    case timedOut
    case serverFailure
    case invalidResponse
}
