/// Constraints on a provider's usage: rates and maximums (ARC-004).
///
/// A provider declares the limits it enforces; a missing limit means the
/// provider states no such constraint. Immutable and equal by content; a
/// change produces a new value.
public struct ProviderLimits: Equatable, Hashable, Sendable {
    /// The maximum requests per minute the provider accepts.
    public let maxRequestsPerMinute: Int?
    /// The maximum tokens per minute the provider accepts.
    public let maxTokensPerMinute: Int?
    /// The maximum context tokens a single request may span.
    public let maxContextTokens: Int?

    /// Creates limits with the stated constraints; a constraint not stated is
    /// `nil`.
    public init(
        maxRequestsPerMinute: Int? = nil,
        maxTokensPerMinute: Int? = nil,
        maxContextTokens: Int? = nil
    ) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxTokensPerMinute = maxTokensPerMinute
        self.maxContextTokens = maxContextTokens
    }
}
