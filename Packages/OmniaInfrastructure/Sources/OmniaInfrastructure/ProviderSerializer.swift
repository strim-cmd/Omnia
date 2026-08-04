import Foundation
import OmniaDomain
import OmniaFoundation

/// The stored representation of the declared provider capabilities (DES-010
/// §3.3). Capabilities are stored by their stable serialized names, sorted.
internal struct ProviderCapabilitiesDTO: Codable, Sendable {
    let capabilities: [String]
}

/// The stored representation of `ProviderMetadata` (DES-010 §3.3).
internal struct ProviderMetadataDTO: Codable, Sendable {
    let displayName: String
}

/// The stored representation of `ProviderLimits` (DES-010 §3.3).
///
/// A constraint not stated by the provider is stored as absent (`nil`).
internal struct ProviderLimitsDTO: Codable, Sendable {
    let maxRequestsPerMinute: Int?
    let maxTokensPerMinute: Int?
    let maxContextTokens: Int?
}

/// The stored representation of a `SemanticVersion` (DES-010 §3.3).
internal struct SemanticVersionDTO: Codable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
}

/// The stored representation of a `ProviderConnection` (DES-010 §3.3).
///
/// The connection records what the provider declares and MUST NOT contain
/// credentials: the stored provider carries references only, never secrets
/// (ARC-004, ARC-005).
internal struct ProviderConnectionDTO: Codable, Sendable {
    let identity: ProviderIdentity
    let capabilities: ProviderCapabilitiesDTO
    let metadata: ProviderMetadataDTO
    let limits: ProviderLimitsDTO
    let version: SemanticVersionDTO
}

/// The stored representation of a `Provider` aggregate (DES-010 §3.3).
///
/// The aggregate stores its declared connection and its lifecycle state; the
/// state is restored by replaying the aggregate's own legal transitions, never
/// by reaching into its private lifecycle (DES-009 §3.1, §3.2).
internal struct ProviderDTO: Codable, Sendable {
    let connection: ProviderConnectionDTO
    let state: String
}

/// Maps a `Provider` aggregate to and from its stored representation
/// (DES-010 §3.3).
///
/// The serializer owns no business rules (ARC-005); it stores and restores the
/// provider exactly as the Domain defines it — its declared connection and its
/// lifecycle state. Credentials never enter the stored form (ARC-001,
/// ARC-005).
internal struct ProviderSerializer: Sendable {
    /// Returns the stored representation of `provider`.
    func toDTO(_ provider: Provider) -> ProviderDTO {
        ProviderDTO(
            connection: ProviderConnectionDTO(
                identity: provider.connection.identity,
                capabilities: ProviderCapabilitiesDTO(
                    capabilities: provider.connection.capabilities.capabilities
                        .map { $0.serializedName }
                        .sorted()
                ),
                metadata: ProviderMetadataDTO(displayName: provider.connection.metadata.displayName),
                limits: ProviderLimitsDTO(
                    maxRequestsPerMinute: provider.connection.limits.maxRequestsPerMinute,
                    maxTokensPerMinute: provider.connection.limits.maxTokensPerMinute,
                    maxContextTokens: provider.connection.limits.maxContextTokens
                ),
                version: SemanticVersionDTO(
                    major: provider.connection.version.major,
                    minor: provider.connection.version.minor,
                    patch: provider.connection.version.patch
                )
            ),
            state: provider.state.serializedName
        )
    }

    /// Restores a `Provider` from its stored representation.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid `Provider` representation.
    func fromDTO(_ dto: ProviderDTO) throws -> Provider {
        guard let state = ProviderState(serializedName: dto.state) else {
            throw RepositoryError.storageUnavailable
        }
        let capabilities = try dto.connection.capabilities.capabilities.map { name -> Capability in
            guard let capability = Capability(serializedName: name) else {
                throw RepositoryError.storageUnavailable
            }
            return capability
        }
        let connection = ProviderConnection(
            identity: dto.connection.identity,
            capabilities: ProviderCapabilities(capabilities: Set(capabilities)),
            metadata: ProviderMetadata(displayName: dto.connection.metadata.displayName),
            limits: ProviderLimits(
                maxRequestsPerMinute: dto.connection.limits.maxRequestsPerMinute,
                maxTokensPerMinute: dto.connection.limits.maxTokensPerMinute,
                maxContextTokens: dto.connection.limits.maxContextTokens
            ),
            version: SemanticVersion(
                major: dto.connection.version.major,
                minor: dto.connection.version.minor,
                patch: dto.connection.version.patch
            )
        )
        let provider = Provider(connection: connection)
        do {
            for next in Self.path(to: state) {
                try provider.transition(to: next)
            }
        } catch {
            throw RepositoryError.storageUnavailable
        }
        return provider
    }

    /// Encodes `provider` to its deterministic JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the aggregate cannot
    ///   be encoded.
    func encode(_ provider: Provider) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(toDTO(provider))
    }

    /// Restores a `Provider` from its JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid `Provider` representation.
    func decode(from data: Data) throws -> Provider {
        let dto: ProviderDTO
        do {
            dto = try JSONDecoder().decode(ProviderDTO.self, from: data)
        } catch {
            throw RepositoryError.storageUnavailable
        }
        return try fromDTO(dto)
    }

    /// The deterministic legal transition path from the aggregate's initial
    /// state (`.registered`) to `target`, replayed on restore (DES-007,
    /// ARC-004).
    private static func path(to target: ProviderState) -> [ProviderState] {
        switch target {
        case .registered: return []
        case .validated: return [.validated]
        case .initializing: return [.validated, .initializing]
        case .ready: return [.validated, .initializing, .ready]
        case .unavailable: return [.validated, .initializing, .unavailable]
        case .disabled: return [.validated, .initializing, .ready, .disabled]
        case .removed: return [.validated, .initializing, .ready, .removed]
        }
    }
}

private extension Capability {
    var serializedName: String {
        switch self {
        case .textGeneration: return "textGeneration"
        case .conversation: return "conversation"
        case .streaming: return "streaming"
        case .vision: return "vision"
        case .imageGeneration: return "imageGeneration"
        case .embeddings: return "embeddings"
        case .toolCalling: return "toolCalling"
        case .structuredOutput: return "structuredOutput"
        case .audio: return "audio"
        case .reasoning: return "reasoning"
        }
    }

    init?(serializedName: String) {
        switch serializedName {
        case "textGeneration": self = .textGeneration
        case "conversation": self = .conversation
        case "streaming": self = .streaming
        case "vision": self = .vision
        case "imageGeneration": self = .imageGeneration
        case "embeddings": self = .embeddings
        case "toolCalling": self = .toolCalling
        case "structuredOutput": self = .structuredOutput
        case "audio": self = .audio
        case "reasoning": self = .reasoning
        default: return nil
        }
    }
}

private extension ProviderState {
    var serializedName: String {
        switch self {
        case .registered: return "registered"
        case .validated: return "validated"
        case .initializing: return "initializing"
        case .ready: return "ready"
        case .unavailable: return "unavailable"
        case .disabled: return "disabled"
        case .removed: return "removed"
        }
    }

    init?(serializedName: String) {
        switch serializedName {
        case "registered": self = .registered
        case "validated": self = .validated
        case "initializing": self = .initializing
        case "ready": self = .ready
        case "unavailable": self = .unavailable
        case "disabled": self = .disabled
        case "removed": self = .removed
        default: return nil
        }
    }
}
