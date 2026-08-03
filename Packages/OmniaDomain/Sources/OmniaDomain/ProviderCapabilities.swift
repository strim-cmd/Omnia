/// The set of capabilities a provider can deliver (ARC-004).
///
/// Immutable and equal by content; a change produces a new value, never an
/// in-place mutation (ARC-001).
public struct ProviderCapabilities: Equatable, Hashable, Sendable {
    /// The capabilities the provider can deliver.
    public let capabilities: Set<Capability>

    /// Creates a capability set from the given capabilities.
    public init(capabilities: Set<Capability>) {
        self.capabilities = capabilities
    }

    /// Returns whether the provider can deliver `capability`.
    public func contains(_ capability: Capability) -> Bool {
        capabilities.contains(capability)
    }
}
