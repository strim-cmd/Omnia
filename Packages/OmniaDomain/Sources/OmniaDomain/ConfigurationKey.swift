/// A typed configuration key: a named slot for a value of type `Value`
/// (DES-009 §3.6).
///
/// The key binds a configuration value to its type; a key of one value type is
/// never interchangeable with a key of another (ARC-003). Immutable and equal
/// by content; a change produces a new key, never an in-place mutation.
public struct ConfigurationKey<Value: Equatable & Sendable>: Equatable, Hashable, Sendable {
    /// The name of the configuration slot.
    public let name: String

    /// Creates a configuration key with the given name.
    public init(_ name: String) {
        self.name = name
    }
}
