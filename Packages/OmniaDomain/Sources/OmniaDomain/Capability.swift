/// A stable capability in the capability set defined by ARC-004.
///
/// A capability expresses what the application needs, provider-agnostically:
/// purpose, responsibilities, constraints, and its relationship to providers
/// (ARC-004). The set is closed and defined by the architecture. The
/// capabilities realized by the Omnia contract are text generation,
/// conversation, and streaming; the remaining capabilities are extension
/// points declared by the contract and not realized (DES-009 §3.1).
public enum Capability: Equatable, Hashable, Sendable {
    /// Produces text from a prompt.
    case textGeneration
    /// Supports multi-turn interaction with context.
    case conversation
    /// Delivers generated content incrementally.
    case streaming
    /// Understands images as input.
    case vision
    /// Produces images from a prompt.
    case imageGeneration
    /// Represents content as vectors.
    case embeddings
    /// Invokes tools on behalf of the model.
    case toolCalling
    /// Produces output conforming to a defined structure.
    case structuredOutput
    /// Supports speech input and output.
    case audio
    /// Performs extended inference before responding.
    case reasoning
}
