import Foundation
import OmniaDomain

/// Shared translation of the transport/credential surface into the safe Domain
/// errors of model discovery and connection testing (DES-009 §3.9, ARC-004).
///
/// The mapping is generic across provider families: Gemini and OpenAI-compatible
/// endpoints surface the same HTTP status evidence, so the same typed terms are
/// produced and raw platform values never cross the Infrastructure boundary.
internal enum ProviderErrorMapping {
    static func catalogError(
        from error: CredentialStorageError
    ) -> ModelCatalogError {
        switch error {
        case .credentialNotFound, .storageUnavailable:
            return .unauthorized
        }
    }

    static func catalogError(
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

    static func connectionError(
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
}
