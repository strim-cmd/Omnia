/// Descriptive information about a provider (ARC-004).
///
/// Immutable and equal by content; a change produces a new value.
public struct ProviderMetadata: Equatable, Hashable, Sendable {
    /// The name shown to the user.
    public let displayName: String

    /// Creates metadata for a provider.
    public init(displayName: String) {
        self.displayName = displayName
    }
}
