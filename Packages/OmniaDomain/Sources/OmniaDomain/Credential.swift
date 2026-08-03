/// A provider credential stored by reference (ARC-005, DES-009 §3.7).
///
/// A credential is an opaque secret value. It never enters logs or analytics:
/// its description is always redacted, and the raw value is reachable only
/// through scoped access (`withValue`). The value itself is held by secure
/// storage in the Infrastructure layer; the Domain declares the contract and
/// never routes or logs credentials (ARC-001, ARC-004, ARC-005).
///
/// Immutable and equal by content; a change produces a new value.
public struct Credential: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let secret: String

    /// Creates a credential from its secret value.
    public init(secret: String) {
        self.secret = secret
    }

    /// Accesses the raw secret value within `body`.
    ///
    /// Scoped access keeps the secret from escaping into logs or analytics;
    /// only the secure-storage implementation reads it (ARC-001).
    public func withValue<Result>(_ body: (String) throws -> Result) rethrows -> Result {
        try body(secret)
    }

    /// A redacted description that never reveals the secret.
    public var description: String {
        "Credential(<redacted>)"
    }

    /// A redacted debug description that never reveals the secret.
    public var debugDescription: String {
        description
    }
}
