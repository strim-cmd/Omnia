/// The failures a capability operation can report (DES-009 §3.11.2).
///
/// The capability error is the Domain-owned abstraction of a failed capability
/// contract: it declares, in Domain terms, that no provider can deliver the
/// requested capability or that the capability response could not be decoded
/// (ARC-004, DES-009 §3.9). It is built on the Foundation error abstraction
/// (DES-001 §3.9): typed, `Equatable`, `Sendable`, and owning no logic
/// (ARC-002). It carries no provider, transport, or decoding detail (ARC-004),
/// and it never wraps or redefines `CredentialStorageError`; credential-resolution
/// failures surface as the existing `CredentialStorageError` (DES-009 §3.7, §3.9).
public enum CapabilityError: Error, Equatable, Sendable {
    /// No provider can deliver the requested capability, or the provider is
    /// unavailable (ARC-004).
    case providerUnavailable
    /// The endpoint could not be reached because the network path is offline
    /// or otherwise unavailable.
    case networkUnavailable
    /// The endpoint rejected the supplied credential.
    case unauthorized
    /// The configured capability endpoint does not exist or is invalid.
    case invalidEndpoint
    /// The provider did not answer within the request timeout.
    case timedOut
    /// The provider rate-limited the request.
    case rateLimited
    /// The provider returned a server-side failure.
    case serverFailure
    /// The conversation's explicitly selected model is no longer available.
    case modelUnavailable(model: ModelReference)
    /// The capability request is invalid in Domain terms.
    case invalidRequest
    /// The capability response could not be decoded (ARC-004).
    case invalidResponse
    /// A stream ended before completion and its interruption event could not be
    /// delivered; the partial content received so far is preserved, never
    /// discarded (ARC-001).
    case streamingInterrupted(partialContent: String)
}
