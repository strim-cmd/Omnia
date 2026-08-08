/// A typed configuration value tagged with the level it applies at.
///
/// Configuration is user-owned; a value holds a value and its level and never
/// embeds product decisions (ARC-003). Immutable and equal by content; a
/// change produces a new value.
public struct ConfigurationValue<Value: Equatable & Sendable>: Equatable, Sendable {
    /// The configuration value.
    public let value: Value
    /// The level at which the value applies.
    public let level: ConfigurationLevel

    /// Creates a configuration value at the given level.
    public init(value: Value, level: ConfigurationLevel) {
        self.value = value
        self.level = level
    }
}
