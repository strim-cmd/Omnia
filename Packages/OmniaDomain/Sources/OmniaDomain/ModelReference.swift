/// A named model a provider offers.
///
/// Used by provider and model selection (ARC-001, ARC-004, ARC-007). A model
/// reference is a value: immutable and equal by content.
public struct ModelReference: Codable, Equatable, Hashable, Sendable {
    /// The provider's name for the model.
    public let name: String

    /// Creates a reference to the named model.
    public init(name: String) {
        self.name = name
    }
}
