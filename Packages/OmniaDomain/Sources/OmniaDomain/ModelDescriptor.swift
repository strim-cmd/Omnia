/// Whether a model is known to support a capability.
///
/// Unknown is deliberately distinct from unsupported: generic OpenAI model
/// listings usually identify models but do not prove vision or document input.
public enum ModelCapabilitySupport: String, Codable, Equatable, Hashable, Sendable {
    case supported
    case unsupported
    case unknown
}

/// Model-specific capability facts. Capabilities absent from both sets are
/// unknown rather than guessed.
public struct ModelCapabilityProfile: Codable, Equatable, Hashable, Sendable {
    public let supported: Set<Capability>
    public let unsupported: Set<Capability>

    public init(
        supported: Set<Capability> = [],
        unsupported: Set<Capability> = []
    ) {
        self.supported = supported.subtracting(unsupported)
        self.unsupported = unsupported
    }

    public func support(for capability: Capability) -> ModelCapabilitySupport {
        if supported.contains(capability) { return .supported }
        if unsupported.contains(capability) { return .unsupported }
        return .unknown
    }

    /// Returns a profile with one explicit fact replaced while preserving all
    /// unrelated model-specific facts. Unknown removes any prior declaration.
    public func replacing(
        _ support: ModelCapabilitySupport,
        for capability: Capability
    ) -> ModelCapabilityProfile {
        var nextSupported = supported
        var nextUnsupported = unsupported
        nextSupported.remove(capability)
        nextUnsupported.remove(capability)
        switch support {
        case .supported: nextSupported.insert(capability)
        case .unsupported: nextUnsupported.insert(capability)
        case .unknown: break
        }
        return ModelCapabilityProfile(
            supported: nextSupported,
            unsupported: nextUnsupported
        )
    }
}

/// The provenance of model metadata, kept explicit so configured fallback and
/// user-declared facts are never presented as endpoint-discovered truth.
public enum ModelDescriptorSource: String, Codable, Equatable, Hashable, Sendable {
    case discovered
    case configuredFallback
    case userDeclared
}

/// A model offered by one provider, together with conservative capability
/// metadata and its provenance.
public struct ModelDescriptor: Codable, Equatable, Hashable, Sendable {
    public let selection: ProviderModelSelection
    public let capabilities: ModelCapabilityProfile
    public let source: ModelDescriptorSource

    public init(
        selection: ProviderModelSelection,
        capabilities: ModelCapabilityProfile = ModelCapabilityProfile(),
        source: ModelDescriptorSource
    ) {
        self.selection = selection
        self.capabilities = capabilities
        self.source = source
    }
}
